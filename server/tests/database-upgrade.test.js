import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {DatabaseSync} from 'node:sqlite';
import {PrismaClient} from '@prisma/client';
import {spawnSync} from 'node:child_process';
import {upgradeDatabase} from '../src/services/database-upgrade.js';
test('legacy upgrade keeps records, backs up first, repeats safely and refuses missing data',async()=>{
 const dir=await fs.mkdtemp(path.join(os.tmpdir(),'assetflow-upgrade-')),file=path.join(dir,'old.db');
 let sql=await fs.readFile('prisma/initial-schema.sql','utf8');
 sql=sql.replace(/CREATE TABLE "peripherals"[\s\S]*?\);/,s=>s.replace(/    "personnel_id" TEXT,\r?\n/,'').replace(/    CONSTRAINT "peripherals_personnel_id_fkey"[^\n]*\n/,''));
 sql=sql.replace(/CREATE INDEX "peripherals_personnel_id_idx"[^;]*;/,'');
 const db=new DatabaseSync(file);db.exec(sql);db.exec(`INSERT INTO personnel (id,full_name) VALUES ('p','Original owner'); INSERT INTO workstations(workstation_tag,personnel_id,user_name) VALUES('WS-OLD','p','Different legacy label'); INSERT INTO peripherals(peripheral_tag,workstation_tag) VALUES('PER-OLD','WS-OLD');`);db.close();
 const prisma=new PrismaClient({datasources:{db:{url:'file:'+file.replaceAll('\\','/')}}});
 try {
  await upgradeDatabase(prisma,file);await upgradeDatabase(prisma,file);
  assert.equal(await prisma.workstation.count(),1);assert.equal(await prisma.peripheral.count(),1);
  assert.equal((await prisma.workstation.findUnique({where:{workstationTag:'WS-OLD'}})).personnelId,'p');
  const backups=(await fs.readdir(dir)).filter(n=>n.startsWith('pre-upgrade-'));assert.equal(backups.length,1);
  const old=new DatabaseSync(path.join(dir,backups[0]),{readOnly:true});assert.equal(old.prepare('select count(*) n from workstations').get().n,1);assert.ok(!old.prepare('pragma table_info(peripherals)').all().some(c=>c.name==='personnel_id'));old.close();
  await assert.rejects(upgradeDatabase(prisma,path.join(dir,'missing.db')),/missing or empty/);
  const missing=path.join(dir,'never-created.db');
  const boot=spawnSync(process.execPath,[path.resolve('src/server.js')],{cwd:dir,env:{...process.env,NODE_ENV:'production',JWT_SECRET:'test-only-secret-at-least-32-characters',DATABASE_URL:'file:'+missing.replaceAll('\\','/')},encoding:'utf8'});assert.equal(boot.status,1);assert.match(boot.stderr,/missing or empty/);await assert.rejects(fs.stat(missing),{code:'ENOENT'});
  const init=spawnSync(process.execPath,[path.resolve('scripts/initialize-database.js')],{cwd:dir,env:{...process.env,DATABASE_URL:'file:'+file.replaceAll('\\','/')},encoding:'utf8'});assert.equal(init.status,1);assert.match(init.stderr,/already exists/);assert.equal(await prisma.workstation.count(),1);
  const fresh=path.join(dir,'fresh.db');
  const created=spawnSync(process.execPath,[path.resolve('scripts/initialize-database.js')],{cwd:dir,env:{...process.env,DATABASE_URL:'file:'+fresh.replaceAll('\\','/'),INITIAL_ADMIN_PASSWORD:'isolated-test-password-only'},encoding:'utf8'});
  assert.equal(created.status,0,created.stderr);
  const freshDb=new DatabaseSync(fresh,{readOnly:true});
  try {assert.equal(freshDb.prepare("select count(*) n from users where role='ADMIN'").get().n,1);}
  finally {freshDb.close();}
 }finally{await prisma.$disconnect();await fs.rm(dir,{recursive:true,force:true});}
});
