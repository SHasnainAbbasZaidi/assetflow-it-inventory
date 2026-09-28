import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {DatabaseSync} from 'node:sqlite';
import jwt from 'jsonwebtoken';
test('individual access is enforced immediately; all restore paths remain admin-only',async()=>{
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'assetflow-access-')),file=path.join(root,'test.db');
 const db=new DatabaseSync(file);db.exec(await fs.readFile('prisma/initial-schema.sql','utf8'));db.close();
 process.env.NODE_ENV='test';process.env.DATABASE_URL='file:'+file.replaceAll('\\','/');process.env.JWT_SECRET='isolated-access-test-secret-123456789';process.env.BACKUP_ROOT=root;
 const {app}=await import('../src/server.js'),{prisma}=await import('../src/prisma.js');
 const server=app.listen(0,'127.0.0.1');await new Promise(r=>server.once('listening',r));
 const tokens=Object.fromEntries(['ADMIN','EDITOR','VIEWER'].map(role=>[role,jwt.sign({email:role+'@test'},process.env.JWT_SECRET)]));
 const send=(route,method='GET',body,role='ADMIN')=>fetch(`http://127.0.0.1:${server.address().port}`+route,{method,headers:{Authorization:'Bearer '+tokens[role],'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});
 try{
  for(const role of Object.keys(tokens))await prisma.appUser.create({data:{email:role+'@test',fullName:role,role}});
  // Account identifiers are normalized by the user management endpoints.
  for(const role of Object.keys(tokens)){await prisma.appUser.update({where:{email:role+'@test'},data:{email:role.toLowerCase()+'@test'}});tokens[role]=jwt.sign({email:role.toLowerCase()+'@test'},process.env.JWT_SECRET);}
  await prisma.workstation.create({data:{workstationTag:'RETIRED',status:'RETIRED'}});
  for(const role of ['VIEWER','EDITOR']){
   assert.equal((await send('/api/assets/workstation/RETIRED/restore','POST',{},role)).status,403);
   assert.equal((await send('/api/assets/workstation/RETIRED/status','PATCH',{status:'IN_STORE'},role)).status,403);
   assert.equal((await send('/api/admin/restore','POST',{},role)).status,403);
  }
  await prisma.personnel.create({data:{id:'edit-owner',fullName:'Edit owner'}});
  assert.equal((await send('/api/workstations','POST',{workstationTag:'EDIT-WS',personnelId:'edit-owner'})).status,201);
  assert.equal((await prisma.workstation.findUnique({where:{workstationTag:'EDIT-WS'}})).status,'ASSIGNED');
  assert.equal((await send('/api/workstations/EDIT-WS','PATCH',{personnelId:null})).status,200);
  assert.equal((await prisma.workstation.findUnique({where:{workstationTag:'EDIT-WS'}})).status,'IN_STORE');
  assert.equal((await send('/api/workstations/EDIT-WS','PATCH',{personnelId:'edit-owner'})).status,200);
  assert.equal((await prisma.workstation.findUnique({where:{workstationTag:'EDIT-WS'}})).status,'ASSIGNED');
  assert.equal((await send('/api/peripherals','POST',{peripheralTag:'EDIT-PER',workstationTag:'EDIT-WS'})).status,201);
  assert.equal((await prisma.peripheral.findUnique({where:{peripheralTag:'EDIT-PER'}})).status,'ASSIGNED');
  assert.equal((await send('/api/peripherals/EDIT-PER','PATCH',{workstationTag:null})).status,200);
  assert.equal((await prisma.peripheral.findUnique({where:{peripheralTag:'EDIT-PER'}})).status,'IN_STORE');
  const customPermissions={view:true,add:true,edit:false,delete:false,export:false,reports:true};
  assert.equal((await send('/api/users/viewer%40test','PATCH',{customPermissions})).status,200);
  assert.equal((await send('/api/workstations','POST',{workstationTag:'NEW'},'VIEWER')).status,201);
  assert.equal((await send('/api/workstations/NEW','PATCH',{ram:'32GB'},'VIEWER')).status,403);
  assert.equal((await send('/api/excel/export','GET',null,'VIEWER')).status,403);
  assert.equal((await send('/api/admin/reports','GET',null,'VIEWER')).status,200);
  assert.equal((await send('/api/admin/reports?format=xlsx','GET',null,'VIEWER')).status,403);
  assert.equal((await send('/api/admin/backups','GET',null,'VIEWER')).status,403);
  assert.equal((await send('/api/users/editor%40test','PATCH',{customPermissions},'VIEWER')).status,403);
  assert.equal((await send('/api/users/viewer%40test','PATCH',{customPermissions:{...customPermissions,restore:true}})).status,400);
  assert.equal((await send('/api/users/viewer%40test','PATCH',{customPermissions:{...customPermissions,add:false,edit:true}})).status,200);
  assert.equal((await send('/api/workstations','POST',{workstationTag:'DENIED'},'VIEWER')).status,403);
  assert.equal((await send('/api/workstations/NEW','PATCH',{ram:'32GB'},'VIEWER')).status,200);
  assert.equal((await send('/api/assets/workstation/RETIRED/status','PATCH',{status:'IN_STORE'},'VIEWER')).status,403);
  assert.equal((await send('/api/assets/workstation/RETIRED/restore','POST',{})).status,200);
  assert.equal((await send('/api/users/viewer%40test','PATCH',{customPermissions:{...customPermissions,view:false}})).status,200);
  for(const route of ['/api/workstations','/api/peripherals','/api/sync','/api/assets/lookup/NEW'])assert.equal((await send(route,'GET',null,'VIEWER')).status,403);
  assert.equal((await send('/api/auth/me','GET',null,'VIEWER')).status,200);
  const settings=await (await send('/api/settings','GET',null,'VIEWER')).json();assert.ok(!JSON.stringify(settings).includes('__access:'));
  assert.equal((await send('/api/users/viewer%40test','PATCH',{customPermissions:null})).status,200);
  assert.equal((await send('/api/workstations','GET',null,'VIEWER')).status,200);
 }finally{await new Promise(r=>server.close(r));await prisma.$disconnect();await fs.rm(root,{recursive:true,force:true});}
});
