import crypto from 'node:crypto';
import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import express from 'express';
import cors from 'cors';
import multer from 'multer';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { z } from 'zod';
import { prisma } from './prisma.js';
import { AssetStatus, exportWorkbook, importWorkbook } from './services/excel-service.js';
import { errorHandler, httpError, notFound } from './middleware/errors.js';
import {databasePath} from './runtime-config.js';
import {upgradeDatabase} from './services/database-upgrade.js';
import { assignAsset, assignmentState } from './services/assignment-service.js';
import { createBackupService } from './services/backup-service.js';
import { adminTools } from './services/admin-tools.js';
import {createVault,aiRoutes,privateSetting} from './services/ai-service.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const publicDir = path.join(__dirname, '../public');

const app = express();
app.set('trust proxy', 'loopback');
const vault = createVault(prisma);
const backups = createBackupService(prisma, process.env.BACKUP_ROOT, vault.validate);
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 25 * 1024 * 1024 } });
const statuses = Object.values(AssetStatus);

// Status validator
const statusSchema = z.preprocess(
  value => typeof value === 'string' ? value.trim().toUpperCase().replaceAll(/[-\s]+/g, '_') : value,
  z.enum(statuses),
);

const workstationSchema = z.object({
  workstationTag: z.string().trim().min(1),
  userName: z.string().trim().optional().nullable(),
  personnelId: z.string().trim().optional().nullable(),
  deviceType: z.string().trim().optional().nullable(),
  motherboard: z.string().trim().optional().nullable(),
  processorGen: z.string().trim().optional().nullable(),
  ram: z.string().trim().optional().nullable(),
  ssd: z.string().trim().optional().nullable(),
  hdd: z.string().trim().optional().nullable(),
  gpu: z.string().trim().optional().nullable(),
  assignedDate: z.coerce.date().optional().nullable(),
  pdfFile: z.string().trim().optional().nullable(),
  notes: z.string().trim().optional().nullable(),
  customFields: z.any().optional().nullable(),
});

const peripheralSchema = z.object({
  peripheralTag: z.string().trim().min(1),
  category: z.string().trim().optional().nullable(),
  modelSpecs: z.string().trim().optional().nullable(),
  workstationTag: z.string().trim().optional().nullable(),
  purchaseDate: z.coerce.date().optional().nullable(),
  warrantyExpiry: z.coerce.date().optional().nullable(),
  brandManufacturer: z.string().trim().optional().nullable(),
  quantity: z.coerce.number().int().nonnegative().optional(),
  storageCapacity: z.string().trim().optional().nullable(),
  gpuSpecs: z.string().trim().optional().nullable(),
  customFields: z.any().optional().nullable(),
});

const personnelSchema = z.object({
  fullName: z.string().trim().min(1, 'Full name is required'),
  department: z.string().trim().optional().nullable(),
  contactEmail: z.string().trim().optional().nullable(),
  notes: z.string().trim().optional().nullable(),
});

const transitions = {
  IN_STORE: ['ASSIGNED', 'RETIRED', 'OUT_OF_ORDER'],
  ASSIGNED: ['IN_STORE', 'RETIRED', 'OUT_OF_ORDER'],
  OUT_OF_ORDER: ['IN_STORE', 'RETIRED'],
  RETIRED: ['IN_STORE'],
  SCRAPPED: [],
};

app.use(cors({ origin: process.env.CORS_ORIGIN?.split(',') || true }));
app.use(express.json({ limit: '10mb' }));

// Serve Native Node.js Web UI static files
app.use(express.static(publicDir));

// Direct download endpoint for Android APK
app.get('/download/app-release.apk', (req, res) => {
  const possibleApkPaths = [
    path.join(__dirname, '../public/download/app-release.apk'),
    path.join(__dirname, '../../inventory_manager_flutter/build/app/outputs/apk/release/app-release.apk'),
    path.join(__dirname, '../app-release.apk'),
  ];
  for (const apkPath of possibleApkPaths) {
    if (fs.existsSync(apkPath)) {
      return res.download(apkPath, 'app-release.apk');
    }
  }
  res.status(404).json({ error: { message: 'APK not found. Please build the release APK and place it in server/public/download/app-release.apk.' } });
});

// Authentication & RBAC Middleware
async function requireAuth(req, res, next) {
  const token = req.headers.authorization?.replace(/^Bearer\s+/i, '') || req.query.token;
  if (!token) return next(httpError(401, 'Authentication is required.', 'UNAUTHORIZED'));
  try {
    req.auth = jwt.verify(token, process.env.JWT_SECRET);
    const user = await prisma.appUser.findUnique({where:{email:req.auth.email}});
    if (!user || user.status !== 'ACTIVE') return next(httpError(401, 'Account is unavailable.', 'UNAUTHORIZED'));
    req.auth = {...req.auth, role:user.role, fullName:user.fullName};
    next();
  } catch {
    next(httpError(401, 'Invalid or expired token.', 'UNAUTHORIZED'));
  }
}

function requireRole(allowedRoles = []) {
  return (req, res, next) => {
    if (!req.auth) return next(httpError(401, 'Authentication is required.', 'UNAUTHORIZED'));
    const userRole = (req.auth.role || 'VIEWER').toUpperCase();
    if (userRole === 'ADMIN' || allowedRoles.includes(userRole)) {
      return next();
    }
    return next(httpError(403, `Access denied: Role "${userRole}" lacks required permission.`, 'FORBIDDEN'));
  };
}

function parsed(schema, body) {
  const result = schema.safeParse(body);
  if (!result.success) throw httpError(400, 'Invalid request body.', 'VALIDATION_ERROR', result.error.flatten());
  return result.data;
}

function audit(tx, userEmail, assetTag, actionTaken) {
  return tx.auditLog.create({
    data: {
      logId: crypto.randomUUID(),
      timestamp: new Date(),
      userEmail: userEmail || 'System',
      assetTag: assetTag || null,
      actionTaken,
    }
  });
}

function serializeCustomFields(cf) {
  if (cf === null || cf === undefined) return undefined;
  if (typeof cf === 'object') return JSON.stringify(cf);
  return String(cf);
}

async function changeStatus(kind, tag, nextStatus, userEmail) {
  const model = kind === 'workstation' ? prisma.workstation : prisma.peripheral;
  const key = kind === 'workstation' ? 'workstationTag' : 'peripheralTag';
  const asset = await model.findUnique({ where: { [key]: tag } });
  if (!asset) throw httpError(404, `${kind} not found.`, 'ASSET_NOT_FOUND');
  if (!transitions[asset.status].includes(nextStatus)) {
    throw httpError(409, `Invalid status transition: ${asset.status} -> ${nextStatus}.`, 'INVALID_STATUS_TRANSITION');
  }
  return prisma.$transaction(async tx => {
    const txModel = kind === 'workstation' ? tx.workstation : tx.peripheral;
    const updated = await txModel.update({ where: { [key]: tag }, data: { status: nextStatus } });
    await audit(tx, userEmail, tag, `${nextStatus === 'IN_STORE' && asset.status === 'RETIRED' ? 'Restored asset' : 'Changed status'}: ${asset.status} -> ${nextStatus}`);
    return updated;
  });
}

// Health Check
app.get('/health', (req, res) => res.json({ ok: true, timestamp: new Date().toISOString() }));
app.use('/api/admin', requireAuth, adminTools(prisma, backups));
app.use('/api/ai', requireAuth, aiRoutes(prisma, vault));

// Authentication Login
app.post('/api/auth/login', async (req, res) => {
  const { email, password } = parsed(z.object({ email: z.string().min(1), password: z.string().min(1) }), req.body);
  const user = await prisma.appUser.findUnique({ where: { email: email.toLowerCase() } });
  if (!user?.passwordHash || !await bcrypt.compare(password, user.passwordHash)) {
    throw httpError(401, 'Invalid email or password.', 'INVALID_CREDENTIALS');
  }
  if (user.status !== 'ACTIVE') {
    throw httpError(403, 'Your account is inactive. Please contact an administrator.', 'ACCOUNT_INACTIVE');
  }
  const secret = process.env.JWT_SECRET;
  const token = jwt.sign({ email: user.email, role: user.role, fullName: user.fullName }, secret, { expiresIn: '12h' });
  res.json({
    token,
    user: { email: user.email, fullName: user.fullName, role: user.role, status: user.status }
  });
});

// Current User Profile
app.get('/api/auth/me', requireAuth, async (req, res) => {
  const user = await prisma.appUser.findUnique({ where: { email: req.auth.email } });
  if (!user) throw httpError(404, 'User account not found.', 'NOT_FOUND');
  const { passwordHash: _, ...rest } = user;
  res.json(rest);
});

// =====================================================================
// PERSONNEL ROUTES (Inventory asset assignment & ownership)
// =====================================================================
app.get('/api/personnel', requireAuth, async (req, res) => {
  const personnelList = await prisma.personnel.findMany({
    include: {
      peripherals: true,
      workstations: {
        include: {
          peripherals: true,
        }
      }
    },
    orderBy: { fullName: 'asc' },
  });

  // Attach aggregated counts
  const enriched = personnelList.map(person => {
    const wsList = person.workstations || [];
    let perCount = (person.peripherals || []).length;
    wsList.forEach(ws => {
      perCount += (ws.peripherals || []).length;
    });
    return {
      ...person,
      workstationsCount: wsList.length,
      peripheralsCount: perCount,
      totalAssetsCount: wsList.length + perCount,
    };
  });

  res.json(enriched);
});

app.get('/api/personnel/:id', requireAuth, async (req, res) => {
  const person = await prisma.personnel.findUnique({
    where: { id: req.params.id },
    include: {
      peripherals: true,
      workstations: {
        include: {
          peripherals: true,
        }
      }
    }
  });
  if (!person) throw httpError(404, 'Personnel record not found.', 'NOT_FOUND');
  res.json(person);
});

app.post('/api/personnel', requireAuth, requireRole(['ADMIN', 'EDITOR']), async (req, res) => {
  const data = parsed(personnelSchema, req.body);
  const created = await prisma.$transaction(async tx => {
    const person = await tx.personnel.create({
      data: {
        id: crypto.randomUUID(),
        fullName: data.fullName,
        department: data.department || null,
        contactEmail: data.contactEmail || null,
        notes: data.notes || null,
      }
    });
    await audit(tx, req.auth.email, null, `Created Personnel profile: ${person.fullName}`);
    return person;
  });
  res.status(201).json(created);
});

app.patch('/api/personnel/:id', requireAuth, requireRole(['ADMIN', 'EDITOR']), async (req, res) => {
  const data = parsed(personnelSchema.partial(), req.body);
  const updated = await prisma.$transaction(async tx => {
    const person = await tx.personnel.update({
      where: { id: req.params.id },
      data: {
        ...(data.fullName !== undefined ? { fullName: data.fullName } : {}),
        ...(data.department !== undefined ? { department: data.department } : {}),
        ...(data.contactEmail !== undefined ? { contactEmail: data.contactEmail } : {}),
        ...(data.notes !== undefined ? { notes: data.notes } : {}),
      }
    });
    // If name changed, update linked workstations' userName field for consistency
    if (data.fullName) {
      await tx.workstation.updateMany({
        where: { personnelId: person.id },
        data: { userName: data.fullName }
      });
    }
    await audit(tx, req.auth.email, null, `Updated Personnel profile: ${person.fullName}`);
    return person;
  });
  res.json(updated);
});

app.delete('/api/personnel/:id', requireAuth, requireRole(['ADMIN']), async (req, res) => {
  const person = await prisma.personnel.findUnique({ where: { id: req.params.id } });
  if (!person) throw httpError(404, 'Personnel record not found.', 'NOT_FOUND');

  await prisma.$transaction(async tx => {
    // Unassign workstations
    await tx.workstation.updateMany({
      where: { personnelId: req.params.id },
      data: { personnelId: null, userName: null }
    });
    await tx.peripheral.updateMany({where:{personnelId:req.params.id,status:'ASSIGNED'},data:{personnelId:null,status:'IN_STORE'}});
    await tx.personnel.delete({ where: { id: req.params.id } });
    await audit(tx, req.auth.email, null, `Deleted Personnel record: ${person.fullName}`);
  });
  res.status(204).send();
});

// =====================================================================
// GLOBAL ASSET LOOKUP
// =====================================================================
app.post('/api/assets/:kind/:tag/assign', requireAuth, requireRole(['ADMIN','EDITOR']), async (req,res) => {
  res.json(await assignAsset(prisma,req.params.kind,req.params.tag,req.body,req.auth.email));
});

app.get('/api/assets/lookup/:tag', requireAuth, async (req, res) => {
  const tag = req.params.tag.trim();
  const workstation = await prisma.workstation.findUnique({
    where: { workstationTag: tag },
    include: { peripherals: true, personnel: true }
  });
  if (workstation) return res.json({ type: 'workstation', data: {...workstation, assignmentState:assignmentState(workstation)} });

  const peripheral = await prisma.peripheral.findUnique({
    where: { peripheralTag: tag },
    include: { personnel:true, workstation: { include: { personnel: true } } }
  });
  if (peripheral) return res.json({ type: 'peripheral', data: {...peripheral, assignmentState:assignmentState(peripheral)} });

  throw httpError(404, `No workstation or peripheral found for tag "${tag}".`, 'ASSET_NOT_FOUND');
});

// =====================================================================
// DELTA SYNC ENDPOINT (For Mobile Client)
// =====================================================================
app.get('/api/sync', requireAuth, async (req, res) => {
  const since = req.query.since ? new Date(req.query.since) : null;
  const [workstations, peripherals, personnel, users, settings, logs] = await Promise.all([
    prisma.workstation.findMany({ include: { peripherals: true, personnel: true } }),
    prisma.peripheral.findMany({ include: { personnel:true, workstation: true } }),
    prisma.personnel.findMany({ include: { workstations: true } }),
    prisma.appUser.findMany({ select: { email: true, fullName: true, role: true, status: true, createdAt: true } }),
    prisma.appSetting.findMany(),
    since && !isNaN(since.getTime())
      ? prisma.auditLog.findMany({ where: { timestamp: { gte: since } }, orderBy: { timestamp: 'asc' } })
      : prisma.auditLog.findMany({ orderBy: { timestamp: 'desc' }, take: 100 })
  ]);
  res.json({
    cursor: new Date().toISOString(),
    workstations,
    peripherals,
    personnel,
    users,
    settings: settings.filter(s => !privateSetting(s.key)),
    logs,
  });
});

// =====================================================================
// WORKSTATIONS ENDPOINTS
// =====================================================================
app.get('/api/workstations', requireAuth, async (req, res) => {
  const workstations = await prisma.workstation.findMany({
    include: { peripherals: true, personnel: true },
    orderBy: { workstationTag: 'asc' },
  });
  res.json(workstations);
});

app.post('/api/workstations', requireAuth, requireRole(['ADMIN', 'EDITOR']), async (req, res) => {
  const data = parsed(workstationSchema, req.body);
  const { workstationTag, customFields, userName, personnelId, ...fields } = data;

  let assignedPersonnelId = personnelId || null;
  let finalUserName = userName || null;

  // Resolve personnel linkage
  if (assignedPersonnelId) {
    const person = await prisma.personnel.findUnique({ where: { id: assignedPersonnelId } });
    if (person) finalUserName = person.fullName;
  } else if (finalUserName) {
    let person = await prisma.personnel.findFirst({ where: { fullName: finalUserName } });
    if (!person) {
      person = await prisma.personnel.create({
        data: { id: crypto.randomUUID(), fullName: finalUserName, department: 'General' }
      });
    }
    assignedPersonnelId = person.id;
  }

  const asset = await prisma.$transaction(async tx => {
    const created = await tx.workstation.create({
      data: {
        workstationTag,
        userName: finalUserName,
        personnelId: assignedPersonnelId,
        ...fields,
        customFields: serializeCustomFields(customFields),
        status: 'IN_STORE',
      }
    });
    await audit(tx, req.auth.email, workstationTag, 'Created workstation');
    return created;
  });
  res.status(201).json(asset);
});

app.patch('/api/workstations/:tag', requireAuth, requireRole(['ADMIN', 'EDITOR']), async (req, res) => {
  const data = parsed(workstationSchema.omit({ workstationTag: true }).partial(), req.body);
  const { customFields, userName, personnelId, ...fields } = data;
  const updateData = { ...fields };

  if (personnelId !== undefined || userName !== undefined) {
    let assignedPersonnelId = personnelId !== undefined ? personnelId : null;
    let finalUserName = userName !== undefined ? userName : null;

    if (assignedPersonnelId) {
      const person = await prisma.personnel.findUnique({ where: { id: assignedPersonnelId } });
      if (person) finalUserName = person.fullName;
    } else if (finalUserName) {
      let person = await prisma.personnel.findFirst({ where: { fullName: finalUserName } });
      if (!person) {
        person = await prisma.personnel.create({
          data: { id: crypto.randomUUID(), fullName: finalUserName, department: 'General' }
        });
      }
      assignedPersonnelId = person.id;
    }

    updateData.personnelId = assignedPersonnelId;
    updateData.userName = finalUserName;
  }

  if (customFields !== undefined) updateData.customFields = serializeCustomFields(customFields);

  const asset = await prisma.$transaction(async tx => {
    const updated = await tx.workstation.update({
      where: { workstationTag: req.params.tag },
      data: updateData,
    });
    await audit(tx, req.auth.email, req.params.tag, 'Updated workstation details');
    return updated;
  });
  res.json(asset);
});

// =====================================================================
// PERIPHERALS ENDPOINTS
// =====================================================================
app.get('/api/peripherals', requireAuth, async (req, res) => {
  const peripherals = await prisma.peripheral.findMany({
    include: { personnel:true, workstation: { include: { personnel: true } } },
    orderBy: { peripheralTag: 'asc' },
  });
  res.json(peripherals);
});

app.post('/api/peripherals', requireAuth, requireRole(['ADMIN', 'EDITOR']), async (req, res) => {
  const data = parsed(peripheralSchema, req.body);
  const { peripheralTag, workstationTag, customFields, ...fields } = data;
  if (workstationTag && !await prisma.workstation.findUnique({ where: { workstationTag } })) {
    throw httpError(409, 'Referenced Workstation Tag does not exist.', 'INVALID_WORKSTATION_REFERENCE');
  }
  const asset = await prisma.$transaction(async tx => {
    const created = await tx.peripheral.create({
      data: {
        peripheralTag,
        workstationTag: workstationTag || null,
        ...fields,
        customFields: serializeCustomFields(customFields),
        status: 'IN_STORE',
        quantity: fields.quantity ?? 1,
      }
    });
    await audit(tx, req.auth.email, peripheralTag, 'Created peripheral');
    return created;
  });
  res.status(201).json(asset);
});

app.patch('/api/peripherals/:tag', requireAuth, requireRole(['ADMIN', 'EDITOR']), async (req, res) => {
  const data = parsed(peripheralSchema.omit({ peripheralTag: true }).partial(), req.body);
  const { customFields, ...fields } = data;
  if (fields.workstationTag && !await prisma.workstation.findUnique({ where: { workstationTag: fields.workstationTag } })) {
    throw httpError(409, 'Referenced Workstation Tag does not exist.', 'INVALID_WORKSTATION_REFERENCE');
  }
  const updateData = { ...fields };
  if (fields.workstationTag !== undefined) updateData.workstationTag = fields.workstationTag || null;
  if (fields.workstationTag) updateData.personnelId = null;
  if (customFields !== undefined) updateData.customFields = serializeCustomFields(customFields);

  const asset = await prisma.$transaction(async tx => {
    const updated = await tx.peripheral.update({
      where: { peripheralTag: req.params.tag },
      data: updateData,
    });
    await audit(tx, req.auth.email, req.params.tag, 'Updated peripheral details');
    return updated;
  });
  res.json(asset);
});

// Asset Lifecycle (Retire / Restore / Status Update)
app.patch('/api/assets/:kind/:tag/status', requireAuth, requireRole(['ADMIN', 'EDITOR']), async (req, res) => {
  if (!['workstation', 'peripheral'].includes(req.params.kind)) {
    throw httpError(400, 'kind must be workstation or peripheral.', 'VALIDATION_ERROR');
  }
  const { status } = parsed(z.object({ status: statusSchema }), req.body);
  res.json(await changeStatus(req.params.kind, req.params.tag, status, req.auth.email));
});

app.post('/api/assets/:kind/:tag/restore', requireAuth, requireRole(['ADMIN', 'EDITOR']), async (req, res) => {
  if (!['workstation', 'peripheral'].includes(req.params.kind)) {
    throw httpError(400, 'kind must be workstation or peripheral.', 'VALIDATION_ERROR');
  }
  res.json(await changeStatus(req.params.kind, req.params.tag, 'IN_STORE', req.auth.email));
});

// =====================================================================
// SETTINGS ENDPOINTS (Company Details, Tag Rules, Themes, Custom Fields)
// =====================================================================
app.get('/api/branding', async (req, res) => {
  const branding = await prisma.appSetting.findMany({
    where: { key: { in: ['companyName', 'companyAddress', 'companyLogo'] } }
  });
  const result = {};
  branding.forEach(setting => { result[setting.key] = setting.value; });
  res.json(result);
});

app.get('/api/settings', requireAuth, async (req, res) => {
  const settings = await prisma.appSetting.findMany();
  const map = {};
  settings.filter(s => !privateSetting(s.key)).forEach(s => { map[s.key] = s.value; });
  res.json(map);
});

app.post('/api/settings', requireAuth, requireRole(['ADMIN']), async (req, res) => {
  const payload = req.body;
  if (typeof payload !== 'object' || payload === null) {
    throw httpError(400, 'Invalid settings payload.', 'VALIDATION_ERROR');
  }
  if (Object.keys(payload).some(privateSetting)) throw httpError(400, 'Use AI API Keys to manage credentials.');
  if (Object.hasOwn(payload, 'companyName')) {
    const companyName = String(payload.companyName).trim();
    if (!companyName || companyName.length > 120) {
      throw httpError(400, 'Company name is required and must be 120 characters or fewer.', 'VALIDATION_ERROR');
    }
    payload.companyName = companyName;
  }
  if (Object.hasOwn(payload, 'companyAddress')) {
    const companyAddress = String(payload.companyAddress).trim();
    if (companyAddress.length > 300) {
      throw httpError(400, 'Company address must be 300 characters or fewer.', 'VALIDATION_ERROR');
    }
    payload.companyAddress = companyAddress;
  }
  if (Object.hasOwn(payload, 'companyLogo')) {
    const companyLogo = String(payload.companyLogo || '');
    const supportedLogo = /^data:image\/(png|jpeg|gif);base64,[a-z0-9+/=\r\n]+$/i;
    if (companyLogo && (!supportedLogo.test(companyLogo) || companyLogo.length > 3_000_000)) {
      throw httpError(400, 'Logo must be a PNG, JPG, or GIF image no larger than 2 MB.', 'VALIDATION_ERROR');
    }
    payload.companyLogo = companyLogo;
  }

  await prisma.$transaction(async tx => {
    for (const [key, value] of Object.entries(payload)) {
      await tx.appSetting.upsert({
        where: { key },
        create: { key, value: String(value) },
        update: { value: String(value) }
      });
    }
    await audit(tx, req.auth.email, null, 'Updated application settings');
  });
  res.json({ ok: true });
});

// Custom Field Definitions
app.get('/api/settings/custom-fields', requireAuth, async (req, res) => {
  const fields = await prisma.customFieldDefinition.findMany({ orderBy: { createdAt: 'asc' } });
  res.json(fields);
});

app.post('/api/settings/custom-fields', requireAuth, requireRole(['ADMIN']), async (req, res) => {
  const { name, label, entityType, fieldType, options, required } = req.body;
  if (!name || !label || !entityType || !fieldType) {
    throw httpError(400, 'name, label, entityType, and fieldType are required.', 'VALIDATION_ERROR');
  }
  const cleanName = name.toLowerCase().replace(/[^a-z0-9_]/g, '_');
  const created = await prisma.customFieldDefinition.create({
    data: {
      id: crypto.randomUUID(),
      name: cleanName,
      label: label.trim(),
      entityType: entityType.toLowerCase(),
      fieldType: fieldType.toLowerCase(),
      options: options ? String(options) : null,
      required: Boolean(required),
    }
  });
  await audit(prisma, req.auth.email, null, `Created custom field: ${label} (${entityType})`);
  res.status(201).json(created);
});

app.delete('/api/settings/custom-fields/:id', requireAuth, requireRole(['ADMIN']), async (req, res) => {
  await prisma.customFieldDefinition.delete({ where: { id: req.params.id } });
  await audit(prisma, req.auth.email, null, `Deleted custom field definition ${req.params.id}`);
  res.status(204).send();
});

// =====================================================================
// USERS & ACCESS ENDPOINTS (Moved under Settings / Admin-Only)
// =====================================================================
app.get('/api/users', requireAuth, requireRole(['ADMIN']), async (req, res) => {
  const users = await prisma.appUser.findMany({ orderBy: { email: 'asc' } });
  res.json(users.map(u => { const { passwordHash, ...rest } = u; return rest; }));
});

app.post('/api/users', requireAuth, requireRole(['ADMIN']), async (req, res) => {
  const { email, fullName, role, status, password } = req.body;
  if (!email || !fullName || !role || !status) {
    throw httpError(400, 'Email, full name, role, and status are required.', 'VALIDATION_ERROR');
  }
  const passwordHash = password ? await bcrypt.hash(password, 10) : null;
  const user = await prisma.$transaction(async tx => {
    const created = await tx.appUser.create({
      data: {
        email: email.toLowerCase().trim(),
        fullName: fullName.trim(),
        role: role.trim().toUpperCase(),
        status: status.trim().toUpperCase(),
        passwordHash,
      }
    });
    await audit(tx, req.auth.email, null, `Created user account: ${created.email} (${created.role})`);
    return created;
  });
  const { passwordHash: _, ...rest } = user;
  res.status(201).json(rest);
});

app.patch('/api/users/:email', requireAuth, requireRole(['ADMIN']), async (req, res) => {
  const email = req.params.email.toLowerCase().trim();
  const { fullName, role, status, password } = req.body;
  const data = {};
  if (fullName) data.fullName = fullName.trim();
  if (role) data.role = role.trim().toUpperCase();
  if (status) data.status = status.trim().toUpperCase();
  if (password) data.passwordHash = await bcrypt.hash(password, 10);

  const user = await prisma.$transaction(async tx => {
    const updated = await tx.appUser.update({ where: { email }, data });
    await audit(tx, req.auth.email, null, `Updated user profile & access: ${email}`);
    return updated;
  });
  const { passwordHash: _, ...rest } = user;
  res.json(rest);
});

app.delete('/api/users/:email', requireAuth, requireRole(['ADMIN']), async (req, res) => {
  const email = req.params.email.toLowerCase().trim();
  if (email === req.auth.email.toLowerCase()) {
    throw httpError(400, 'You cannot delete your own active administrator account.', 'SELF_DELETE_FORBIDDEN');
  }
  await prisma.$transaction(async tx => {
    await tx.appUser.delete({ where: { email } });
    await audit(tx, req.auth.email, null, `Deleted user account: ${email}`);
  });
  res.status(204).send();
});

// =====================================================================
// AUDIT LOGS ENDPOINTS
// =====================================================================
app.get('/api/logs', requireAuth, async (req, res) => {
  const { user, asset, from, to } = req.query;
  const where = {};
  if (user) where.userEmail = { contains: String(user) };
  if (asset) where.assetTag = { contains: String(asset) };
  if (from || to) {
    where.timestamp = {};
    if (from) where.timestamp.gte = new Date(String(from));
    if (to) where.timestamp.lte = new Date(String(to));
  }
  const logs = await prisma.auditLog.findMany({
    where,
    orderBy: { timestamp: 'desc' },
    take: 200,
  });
  res.json(logs);
});

// =====================================================================
// EXCEL IMPORT & EXPORT
// =====================================================================
app.post('/api/excel/import', requireAuth, requireRole(['ADMIN']), upload.single('file'), async (req, res) => {
  if (!req.file || !req.file.originalname.toLowerCase().endsWith('.xlsx')) {
    throw httpError(400, 'Please upload one .xlsx file in the "file" form field.', 'INVALID_UPLOAD');
  }
  const result = await importWorkbook(req.file.buffer, prisma);
  await prisma.auditLog.create({
    data: {
      logId: crypto.randomUUID(),
      timestamp: new Date(),
      userEmail: req.auth.email,
      actionTaken: `Imported Excel database: ${result.inserted} inserted, ${result.updated} updated, ${result.skipped} skipped`
    }
  });
  res.status(200).json(result);
});

app.get('/api/excel/export', requireAuth, async (req, res) => {
  const content = await exportWorkbook(prisma);
  res.type('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
     .attachment('IT Asset Database.xlsx')
     .send(Buffer.from(content));
});

// Single Page Application route fallback
app.use((req, res, next) => {
  if (req.method === 'GET' && !req.path.startsWith('/api/') && !req.path.startsWith('/health')) {
    const indexHtml = path.join(publicDir, 'index.html');
    if (fs.existsSync(indexHtml)) {
      return res.sendFile(indexHtml);
    }
  }
  next();
});

app.use(notFound);
app.use(errorHandler);

const port = Number(process.env.PORT || 5555);

async function startServer() {
  if (!process.env.JWT_SECRET || process.env.JWT_SECRET.length < 32) throw new Error('Set a persistent JWT_SECRET of at least 32 characters.');
  await upgradeDatabase(prisma,databasePath);
  backups.start(24);

  app.listen(port, '0.0.0.0', () => {
    console.log(`AssetFlow Node API & Web Server listening on port ${port}`);
  });
}

export { app };
if (process.env.NODE_ENV !== 'test') startServer().catch(err => {
  console.error('Failed to start AssetFlow:', err.message);
  process.exitCode=1;
  void prisma.$disconnect();
});
