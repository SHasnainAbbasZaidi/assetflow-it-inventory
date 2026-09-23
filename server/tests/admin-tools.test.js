import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {DatabaseSync} from 'node:sqlite';
import express from 'express';
import {PrismaClient} from '@prisma/client';
import ExcelJS from 'exceljs';
import {createBackupService,snapshot} from '../src/services/backup-service.js';
import {adminTools} from '../src/services/admin-tools.js';
import {errorHandler} from '../src/middleware/errors.js';

test('admin reports, silent delete and complete transactional backup/restore',async()=>{
  const root=await fs.mkdtemp(path.join(os.tmpdir(),'assetflow-admin-'));
  const url='file:'+path.join(root,'isolated.db').replaceAll('\\','/');
  new DatabaseSync(path.join(root,'isolated.db')).close();
  const init=spawnSync(process.execPath,['node_modules/prisma/build/index.js','db','push','--skip-generate'],{env:{...process.env,DATABASE_URL:url},encoding:'utf8'});
  assert.equal(init.status,0,init.stdout+'\n'+init.stderr);
  const prisma=new PrismaClient({datasources:{db:{url}}});
  let server;
  try {
    await prisma.appUser.create({data:{email:'admin@test',fullName:'Admin',role:'ADMIN',passwordHash:'test-hash'}});
    await prisma.appUser.create({data:{email:'viewer@test',fullName:'Viewer',role:'VIEWER'}});
    await prisma.appUser.create({data:{email:'editor@test',fullName:'Editor',role:'EDITOR'}});
    await prisma.personnel.create({data:{id:'p',fullName:'Person',department:'IT'}});
    await prisma.workstation.create({data:{workstationTag:'WS-1',personnelId:'p',status:'ASSIGNED'}});
    await prisma.peripheral.create({data:{peripheralTag:'PER-1',workstationTag:'WS-1',status:'ASSIGNED',customFields:'{"color":"blue"}'}});
    await prisma.peripheral.create({data:{peripheralTag:'PER-2',personnelId:'p',status:'ASSIGNED'}});
    await prisma.appSetting.create({data:{key:'companyLogo',value:'data:image/png;base64,abc'}});
    await prisma.customFieldDefinition.create({data:{name:'color',label:'Color',entityType:'peripheral',fieldType:'text'}});
    await prisma.auditLog.create({data:{logId:'log',timestamp:new Date(),assetTag:'WS-1',actionTaken:'Original history'}});
    const backups=createBackupService(prisma,root);
    const app=express();app.use(express.json());app.use((req,res,next)=>{req.auth={email:req.headers['x-user']||'admin@test'};next();});app.use('/api/admin',adminTools(prisma,backups));app.use(errorHandler);
    server=app.listen(0,'127.0.0.1');await new Promise(r=>server.once('listening',r));
    const base=`http://127.0.0.1:${server.address().port}/api/admin`;
    const post=(route,body={},user='admin@test')=>fetch(base+route,{method:'POST',headers:{'Content-Type':'application/json','x-user':user},body:JSON.stringify(body)});
    for(const user of ['viewer@test','editor@test','missing@test']) {
      for(const route of ['/reports','/backups'])assert.equal((await fetch(base+route,{headers:{'x-user':user}})).status,403);
      for(const route of ['/backups','/restore','/super-delete'])assert.equal((await post(route,{},user)).status,403);
    }
    const report=await (await fetch(base+'/reports?type=personnel')).json();assert.equal(report.total,3);assert.ok(report.rows.every(r=>r.person==='Person'));
    const book=new ExcelJS.Workbook();await book.xlsx.load(Buffer.from(await (await fetch(base+'/reports?format=xlsx')).arrayBuffer()));assert.equal(book.worksheets[0].rowCount,4);
    const before=await snapshot(prisma);
    const manual=await backups.manual();const saved=JSON.parse((await backups.read('manual',manual.name)).toString());
    assert.equal(saved.tables.appUser[0].passwordHash,'test-hash');
    for(let i=0;i<12;i++)await backups.automatic();
    assert.equal((await backups.list('automatic')).length,10);assert.equal((await backups.list('excel')).length,10);assert.equal((await backups.list('manual')).length,1);
    await assert.rejects(backups.read('manual','../isolated.db'),{status:400});
    const malformed={...saved,checksum:'bad'};await assert.rejects(backups.restore(malformed),{status:400});
    assert.equal((await snapshot(prisma)).checksum,before.checksum);
    const invalid=structuredClone(saved);invalid.tables.peripheral[0].workstationTag='missing';invalid.checksum=crypto.createHash('sha256').update(JSON.stringify(invalid.tables)).digest('hex');
    await assert.rejects(backups.restore(invalid));assert.equal((await snapshot(prisma)).checksum,before.checksum);
    assert.equal((await post('/super-delete',{kind:'workstation',tag:'WS-1',confirmation:'wrong'})).status,400);
    assert.equal((await post('/super-delete',{kind:'workstation',tag:'WS-1',confirmation:'WS-1'})).status,204);
    assert.equal(await prisma.workstation.count(),0);assert.equal(await prisma.peripheral.count(),2);assert.equal(await prisma.auditLog.count(),1);
    const linked=await prisma.peripheral.findUnique({where:{peripheralTag:'PER-1'}});assert.equal(linked.workstationTag,null);assert.equal(linked.status,'IN_STORE');
    assert.equal((await post('/super-delete',{kind:'peripheral',tag:'PER-2',confirmation:'PER-2'})).status,204);assert.equal(await prisma.auditLog.count(),1);
    const result=await post('/restore',{kind:'manual',name:manual.name,confirmation:'RESTORE'});assert.equal(result.status,200,await result.text());
    assert.equal((await snapshot(prisma)).checksum,before.checksum);
    assert.equal((await backups.list('manual')).length,3);
  } finally {if(server)await new Promise(r=>server.close(r));await prisma.$disconnect();await fs.rm(root,{recursive:true,force:true});}
});
