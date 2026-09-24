import {categoryWorkbook,inventoryGroups} from './hardware-workbook.js';
// AssetFlow — a product of Mahzaidex Tech Developed by Hasnain Zaidi.
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { Prisma } from '@prisma/client';
import { z } from 'zod';
import ExcelJS from 'exceljs';
import { httpError } from '../middleware/errors.js';

const appDir = fileURLToPath(new URL('../../', import.meta.url));
export const modelNames = ['personnel', 'workstation', 'peripheral', 'appUser', 'customFieldDefinition', 'appSetting', 'auditLog'];
const digest = tables => crypto.createHash('sha256').update(JSON.stringify(tables)).digest('hex');
const schemas = Object.fromEntries(Prisma.dmmf.datamodel.models.map(model => {
  const fields = {};
  for (const f of model.fields.filter(f => f.kind === 'scalar')) {
    let rule = f.type === 'Int' ? z.number().int() : f.type === 'Boolean' ? z.boolean() : f.type === 'DateTime' ? z.string().datetime() : z.string();
    fields[f.name] = f.isRequired ? rule : rule.nullable();
  }
  return [model.name[0].toLowerCase() + model.name.slice(1), z.array(z.object(fields).strict())];
}));
const stateSchema = z.object(Object.fromEntries(modelNames.map(n => [n, schemas[n]]))).strict();

export async function snapshot(prisma) {
  const rows = await prisma.$transaction(modelNames.map(n => prisma[n].findMany()));
  const tables = JSON.parse(JSON.stringify(Object.fromEntries(modelNames.map((n,i) => [n,rows[i]]))));
  return {format:'assetflow-state', version:1, createdAt:new Date().toISOString(), checksum:digest(tables), inventoryGroups:inventoryGroups(tables), tables};
}

export function validateState(input) {
  if (input?.format !== 'assetflow-state' || input.version !== 1 || !input.tables || input.checksum !== digest(input.tables)) throw httpError(400,'Invalid or damaged AssetFlow backup.');
  const result = stateSchema.safeParse(input.tables);
  if (!result.success) throw httpError(400,'Backup fields do not match this application version.');
  if (!result.data.appUser.some(u => u.role === 'ADMIN' && u.status === 'ACTIVE' && u.passwordHash)) throw httpError(400,'Backup must contain an active administrator with a password.');
  return result.data;
}

export async function stateWorkbook(state) {
  const book = new ExcelJS.Workbook();
  await book.xlsx.load(await categoryWorkbook(state.tables));
  book.creator = 'Mahzaidex Tech / Hasnain Zaidi';
  for (const name of ['customFieldDefinition','appSetting']) {
    const rows = name==='appSetting' ? state.tables[name].filter(r=>!r.key.startsWith('__') && !/api.?key|secret|token/i.test(r.key)) : state.tables[name];
    const fields = Object.keys(schemas[name].element.shape).filter(k => k !== 'passwordHash');
    const sheet = book.addWorksheet(name);
    sheet.addRow(fields);
    for (const row of rows) sheet.addRow(fields.map(k => row[k]));
    sheet.getRow(1).font = {bold:true};
    sheet.views = [{state:'frozen',ySplit:1}];
    fields.forEach((f,i) => sheet.getColumn(i+1).width = Math.min(40,Math.max(18,f.length+4)));
  }
  return Buffer.from(await book.xlsx.writeBuffer());
}

export function createBackupService(prisma, root = appDir, validateSecrets = async () => {}) {
  const folders = {excel:path.join(root,'Backup'), automatic:path.join(root,'AutomaticBackups'), manual:path.join(root,'ManualBackups')};
  let tail = Promise.resolve();
  const exclusive = fn => { const next = tail.then(fn); tail = next.catch(()=>{}); return next; };
  const pattern = /^assetflow-[0-9TZ-]+-[a-f0-9-]+\.(json|xlsx)$/;
  async function list(kind) {
    await fs.mkdir(folders[kind], {recursive:true});
    const entries = await fs.readdir(folders[kind]);
    return (await Promise.all(entries.filter(n=>pattern.test(n)).map(async name => {
      const stat = await fs.stat(path.join(folders[kind],name));
      return {name, bytes:stat.size, createdAt:stat.mtime.toISOString()};
    }))).sort((a,b)=>b.name.localeCompare(a.name));
  }
  async function save(kind, content) {
    await fs.mkdir(folders[kind],{recursive:true});
    const name = `assetflow-${new Date().toISOString().replace(/[.:]/g,'-')}-${crypto.randomUUID()}.${kind==='excel'?'xlsx':'json'}`;
    const target = path.join(folders[kind],name);
    await fs.writeFile(target+'.tmp',content,{flag:'wx',mode:0o600});
    await fs.rename(target+'.tmp',target);
    if (kind !== 'manual') for (const old of (await list(kind)).slice(10)) await fs.unlink(path.join(folders[kind],old.name));
    return {name,kind};
  }
  async function read(kind,name) {
    if (!folders[kind] || !pattern.test(name) || path.basename(name)!==name) throw httpError(400,'Invalid backup name.');
    try { return await fs.readFile(path.join(folders[kind],name)); } catch(e) { if(e.code==='ENOENT') throw httpError(404,'Backup not found.'); throw e; }
  }
  const manual = () => exclusive(async()=>save('manual',JSON.stringify(await snapshot(prisma))));
  const automatic = () => exclusive(async()=>{
    const state = await snapshot(prisma);
    const full = await save('automatic',JSON.stringify(state));
    await save('excel',await stateWorkbook(state));
    return full;
  });
  const restore = input => exclusive(async()=>{
    const tables = validateState(input);
    await validateSecrets(tables.appSetting);
    const recovery = await save('manual',JSON.stringify(await snapshot(prisma)));
    await prisma.$transaction(async tx => {
      for (const name of [...modelNames].reverse()) await tx[name].deleteMany();
      for (const name of modelNames) for (const row of tables[name]) await tx[name].create({data:row});
      if ((await tx.$queryRawUnsafe('PRAGMA foreign_key_check')).length) throw httpError(400,'Backup contains invalid relationships.');
    },{timeout:120000});
    return {restored:true,recovery};
  });
  let lastError = null;
  async function scheduled() { try { await automatic(); lastError=null; } catch(e) { lastError='Automatic backup failed. Check server storage and database availability.'; console.error(lastError,e); } }
  async function due(interval) {
    const [a,e] = await Promise.all([list('automatic'),list('excel')]);
    if (!a[0] || !e[0] || Date.now()-Math.min(Date.parse(a[0].createdAt),Date.parse(e[0].createdAt))>=interval) await scheduled();
  }
  function start(hours=24) {
    const interval = (Number.isFinite(hours) && hours>=1 ? hours : 24)*3600000;
    const tick = ()=>due(interval).catch(e=>{lastError='Automatic backup failed. Check server storage.';console.error(lastError,e);});
    void tick();
    const timer=setInterval(tick,60000);timer.unref();return timer;
  }
  return {list,read,manual,automatic,restore,start,status:()=>({lastError})};
}
