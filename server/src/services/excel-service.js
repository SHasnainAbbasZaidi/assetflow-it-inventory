import {categoryWorkbook,importCategoryWorkbook} from './hardware-workbook.js';
import {httpError} from '../middleware/errors.js';
import ExcelJS from 'exceljs';
import {registerScrapped} from './scrap-service.js';

export const AssetStatus = {
  IN_STORE: 'IN_STORE',
  ASSIGNED: 'ASSIGNED',
  RETIRED: 'RETIRED',
  SCRAPPED: 'SCRAPPED',
  OUT_OF_ORDER: 'OUT_OF_ORDER',
};

export const SHEETS = {
  Workstations: ['Workstation Tag', 'User Name', 'Device Type', 'Motherboard', 'Processor & Gen', 'RAM', 'SSD', 'HDD', 'GPU', 'Status', 'Assigned Date', 'PDF File', 'Notes'],
  Peripherals: ['Peripheral Tag', 'Category', 'Model Specs', 'Workstation Tag', 'Status', 'Purchase Date', 'Warranty Expiry', 'Brand / Manufacturer', 'Quantity', 'Storage Capacity', 'GPU Specs'],
  Users: ['Email', 'Full Name', 'Role', 'Status'],
  'Audit Logs': ['Log ID', 'Timestamp', 'User Email', 'Asset Tag', 'Action Taken'],
};

const toText = (value) => value == null ? '' : String(value).trim();
const toDate = (value) => {
  if (value == null || value === '') return null;
  const parsed = value instanceof Date ? value : new Date(value);
  return Number.isNaN(parsed.getTime()) ? undefined : parsed;
};
const statusMap = Object.fromEntries(Object.values(AssetStatus).map(value => [value.replaceAll('_', ' '), value]));
function parseStatus(value) {
  const normalized = toText(value).toUpperCase().replaceAll('-', ' ').replace(/\s+/g, ' ');
  return statusMap[normalized] || (normalized === 'AVAILABLE' ? AssetStatus.IN_STORE : normalized === 'IN USE' ? AssetStatus.ASSIGNED : undefined);
}
function rowValues(row, headers) {
  const values = {};
  headers.forEach((header, i) => { values[header] = row.getCell(i + 1).value; });
  return values;
}
function summary() { return { inserted: 0, updated: 0, skipped: 0, errors: [] }; }
function fail(result, sheet, row, reason) { result.skipped++; result.errors.push({ sheet, row, reason }); }
function assertHeaders(sheet, expected) {
  const actual = sheet.getRow(1).values.slice(1).map(toText);
  if (expected.some((header, i) => actual[i] !== header)) throw new Error(`Sheet "${sheet.name}" must use the required headers and column order.`);
}

/** Imports independently-valid rows. A bad row never rolls back other rows. */
export async function importWorkbook(buffer, prisma, operator) {
  const workbook = new ExcelJS.Workbook();
  await workbook.xlsx.load(buffer);
  if(workbook.getWorksheet('Workstations')?.getRow(1).getCell(1).value==='Record Type') {
    try {return await importCategoryWorkbook(workbook,prisma,operator);}
    catch(error){throw httpError(400,error.code?'Workbook contains invalid values or references missing records. No rows were changed.':error.message);}
  }
  for (const [name, headers] of Object.entries(SHEETS)) {
    const sheet = workbook.getWorksheet(name);
    if (!sheet) throw new Error(`Missing required sheet: ${name}`);
    assertHeaders(sheet, headers);
  }
  const result = summary();
  const seen = new Map();
  const duplicate = (sheet, key, row) => {
    const token = `${sheet}:${key}`;
    if (seen.has(token)) { fail(result, sheet, row, `Duplicate identifier in workbook (also row ${seen.get(token)}).`); return true; }
    seen.set(token, row); return false;
  };

  // Users first so a workbook can contain employee data used by its assets.
  for (const row of workbook.getWorksheet('Users').getRows(2, workbook.getWorksheet('Users').rowCount - 1) || []) {
    const v = rowValues(row, SHEETS.Users); const email = toText(v.Email).toLowerCase();
    if (!email || !toText(v['Full Name']) || !toText(v.Role) || !toText(v.Status)) { fail(result, 'Users', row.number, 'Email, Full Name, Role, and Status are required.'); continue; }
    if (duplicate('Users', email, row.number)) continue;
    const exists = await prisma.appUser.findUnique({ where: { email } });
    await prisma.appUser.upsert({ where: { email }, create: { email, fullName: toText(v['Full Name']), role: toText(v.Role), status: toText(v.Status) }, update: { fullName: toText(v['Full Name']), role: toText(v.Role), status: toText(v.Status) } });
    result[exists ? 'updated' : 'inserted']++;
  }
  for (const row of workbook.getWorksheet('Workstations').getRows(2, workbook.getWorksheet('Workstations').rowCount - 1) || []) {
    const v = rowValues(row, SHEETS.Workstations); const tag = toText(v['Workstation Tag']); const status = parseStatus(toText(v.Status) || 'IN STORE'); const assignedDate = toDate(v['Assigned Date']);
    if (!tag || !status || assignedDate === undefined) { fail(result, 'Workstations', row.number, !tag ? 'Workstation Tag is required.' : !status ? 'Invalid Status.' : 'Invalid Assigned Date.'); continue; }
    if (duplicate('Workstations', tag, row.number)) continue;
    const userName = toText(v['User Name']) || null;
    let personnelId = null;
    if (userName) {
      let person = await prisma.personnel.findFirst({ where: { fullName: userName } });
      if (!person) {
        person = await prisma.personnel.create({
          data: { fullName: userName, department: 'General' }
        });
      }
      personnelId = person.id;
    }

    const data = { userName, personnelId, deviceType: toText(v['Device Type']) || null, motherboard: toText(v.Motherboard) || null, processorGen: toText(v['Processor & Gen']) || null, ram: toText(v.RAM) || null, ssd: toText(v.SSD) || null, hdd: toText(v.HDD) || null, gpu: toText(v.GPU) || null, status, assignedDate, pdfFile: toText(v['PDF File']) || null, notes: toText(v.Notes) || null };
    const exists = await prisma.workstation.findUnique({ where: { workstationTag: tag } });
    if(exists?.status==='SCRAPPED') { fail(result,'Workstations',row.number,'Scrapped items cannot be overwritten by import.'); continue; }
    try {
      await prisma.$transaction(async tx=>{
        await tx.workstation.upsert({where:{workstationTag:tag},create:{workstationTag:tag,...data},update:data});
        if(status==='SCRAPPED'){if(!operator)throw new Error('A verified operator is required to import scrapped items.');await registerScrapped(tx,'workstation',tag,operator);}
      });
      result[exists?'updated':'inserted']++;
    }catch(error){fail(result,'Workstations',row.number,error.message);}
  }
  for (const row of workbook.getWorksheet('Peripherals').getRows(2, workbook.getWorksheet('Peripherals').rowCount - 1) || []) {
    const v = rowValues(row, SHEETS.Peripherals); const tag = toText(v['Peripheral Tag']); const wsTag = toText(v['Workstation Tag']); const status = parseStatus(toText(v.Status) || 'IN STORE'); const purchaseDate = toDate(v['Purchase Date']); const warrantyExpiry = toDate(v['Warranty Expiry']); const quantity = Number(v.Quantity ?? 1);
    if (!tag || !status || purchaseDate === undefined || warrantyExpiry === undefined || !Number.isInteger(quantity) || quantity < 0) { fail(result, 'Peripherals', row.number, 'Peripheral Tag, valid Status, valid dates, and non-negative integer Quantity are required.'); continue; }
    if (duplicate('Peripherals', tag, row.number)) continue;
    if (wsTag && !await prisma.workstation.findUnique({ where: { workstationTag: wsTag }, select: { workstationTag: true } })) { fail(result, 'Peripherals', row.number, `Workstation Tag "${wsTag}" does not exist.`); continue; }
    const data = { category: toText(v.Category) || null, modelSpecs: toText(v['Model Specs']) || null, workstationTag: wsTag || null, status, purchaseDate, warrantyExpiry, brandManufacturer: toText(v['Brand / Manufacturer']) || null, quantity, storageCapacity: toText(v['Storage Capacity']) || null, gpuSpecs: toText(v['GPU Specs']) || null };
    const exists = await prisma.peripheral.findUnique({ where: { peripheralTag: tag } });
    if(exists?.status==='SCRAPPED') { fail(result,'Peripherals',row.number,'Scrapped items cannot be overwritten by import.'); continue; }
    try {
      await prisma.$transaction(async tx=>{
        await tx.peripheral.upsert({where:{peripheralTag:tag},create:{peripheralTag:tag,...data},update:data});
        if(status==='SCRAPPED'){if(!operator)throw new Error('A verified operator is required to import scrapped items.');await registerScrapped(tx,'peripheral',tag,operator);}
      });
      result[exists?'updated':'inserted']++;
    }catch(error){fail(result,'Peripherals',row.number,error.message);}
  }
  for (const row of workbook.getWorksheet('Audit Logs').getRows(2, workbook.getWorksheet('Audit Logs').rowCount - 1) || []) {
    const v = rowValues(row, SHEETS['Audit Logs']); const logId = toText(v['Log ID']); const timestamp = toDate(v.Timestamp);
    if (!logId || timestamp === undefined || !toText(v['Action Taken'])) { fail(result, 'Audit Logs', row.number, 'Log ID, valid Timestamp, and Action Taken are required.'); continue; }
    if (duplicate('Audit Logs', logId, row.number)) continue;
    if (await prisma.auditLog.findUnique({ where: { logId } })) { fail(result, 'Audit Logs', row.number, 'Log ID already exists; audit logs are append-only.'); continue; }
    await prisma.auditLog.create({ data: { logId, timestamp, userEmail: toText(v['User Email']) || null, assetTag: toText(v['Asset Tag']) || null, actionTaken: toText(v['Action Taken']) } }); result.inserted++;
  }
  return result;
}

const statusLabel = value => value.replaceAll('_', ' ').replace(/\b\w/g, char => char.toUpperCase());
function addSheet(workbook, name, headers, rows) {
  const sheet = workbook.addWorksheet(name); sheet.addRow(headers); sheet.getRow(1).font = { bold: true }; sheet.views = [{ state: 'frozen', ySplit: 1 }];
  rows.forEach(row => sheet.addRow(row)); headers.forEach((header, i) => { sheet.getColumn(i + 1).width = Math.max(14, header.length + 2); });
  return sheet;
}
export async function exportWorkbook(prisma) {
  const names=['workstation','peripheral','personnel','appUser','auditLog'];
  const rows=await prisma.$transaction(names.map(name=>prisma[name].findMany()));
  return categoryWorkbook(Object.fromEntries(names.map((name,i)=>[name,rows[i]])));
}
