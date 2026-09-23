import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import { Prisma } from '@prisma/client';
export async function upgradeDatabase(prisma, databasePath) {
  const stat=await fs.stat(databasePath).catch(()=>null);
  if(!stat?.isFile() || stat.size===0) throw new Error('Configured database is missing or empty. Startup stopped to protect existing data. Check DATABASE_URL and your persistent volume; use db:init only for a genuinely new installation.');
  const tables=await prisma.$queryRawUnsafe("SELECT name FROM sqlite_master WHERE type='table'");
  for(const model of Prisma.dmmf.datamodel.models) if(!tables.some(t=>t.name===(model.dbName||model.name))) throw new Error(`Required table ${model.dbName||model.name} is missing. Startup stopped; select or restore the correct database.`);
  const columns=await prisma.$queryRawUnsafe('PRAGMA table_info(peripherals)');
  const indexes=await prisma.$queryRawUnsafe('PRAGMA index_list(peripherals)');
  if(!columns.some(c=>c.name==='personnel_id') || !indexes.some(i=>i.name==='peripherals_personnel_id_idx')) {
    const backup=path.join(path.dirname(databasePath),`pre-upgrade-${Date.now()}-${crypto.randomUUID()}.db`);
    await prisma.$executeRawUnsafe('VACUUM INTO ?',backup);
    await prisma.$transaction(async tx=>{
      if(!columns.some(c=>c.name==='personnel_id')) await tx.$executeRawUnsafe('ALTER TABLE peripherals ADD COLUMN personnel_id TEXT REFERENCES personnel(id) ON DELETE SET NULL');
      await tx.$executeRawUnsafe('CREATE INDEX IF NOT EXISTS peripherals_personnel_id_idx ON peripherals(personnel_id)');
    });
    console.info('Database upgraded safely. A pre-upgrade backup was saved beside the active database.');
  }
  for(const model of Prisma.dmmf.datamodel.models) {
    const table=model.dbName||model.name;
    const actual=await prisma.$queryRawUnsafe(`PRAGMA table_info("${table}")`);
    for(const field of model.fields.filter(f=>f.kind==='scalar')) if(!actual.some(c=>c.name===(field.dbName||field.name))) throw new Error(`Incompatible database: missing ${table}.${field.dbName||field.name}. No records were reset.`);
  }
}
