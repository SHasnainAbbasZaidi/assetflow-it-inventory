import {test} from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import fs from 'node:fs/promises';
import path from 'node:path';
import jwt from 'jsonwebtoken';

test('batch API creates individual items atomically and enforces add permission',async()=>{
 const folder=await fs.mkdtemp(path.resolve('../.build-tools/batch-test-'));const file=path.join(folder,'test.db');
 const db=new DatabaseSync(file);db.exec(await fs.readFile('prisma/initial-schema.sql','utf8'));db.close();
 process.env.NODE_ENV='test';process.env.DATABASE_URL='file:'+file.replaceAll('\\','/');process.env.JWT_SECRET='batch-test-secret';process.env.BACKUP_ROOT=folder;
 const {app}=await import('../src/server.js'),{prisma}=await import('../src/prisma.js');
 const server=app.listen(0,'127.0.0.1');await new Promise(r=>server.once('listening',r));
 const base='http://127.0.0.1:'+server.address().port;
 try{
  for(const role of ['ADMIN','VIEWER'])await prisma.appUser.create({data:{email:role,role,fullName:role}});
  const send=(body,role='ADMIN')=>fetch(base+'/api/peripherals/batch',{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+jwt.sign({email:role,role},process.env.JWT_SECRET)},body:JSON.stringify(body)});
  const common={category:'Mouse',brandManufacturer:'Logitech',modelSpecs:'M100',purchaseDate:'2026-10-05',customFields:{receiveDate:'2026-10-05'}};
  const tags=Array.from({length:10},(_,i)=>'BATCH-'+i);
  const res=await send({quantity:10,tags,common});assert.equal(res.status,201);const result=await res.json();assert.equal(result.count,10);
  assert.equal(await prisma.peripheral.count(),10);assert.equal(await prisma.auditLog.count(),10);
  for(const item of result.items){assert.equal(item.quantity,1);assert.equal(item.brandManufacturer,'Logitech');assert.equal(JSON.parse(item.customFields).receiveDate,'2026-10-05');}
  const before=await prisma.auditLog.count();
  for(const body of [{quantity:2,tags:['NEW','BATCH-1'],common},{quantity:2,tags:['NEW',' NEW '],common},{quantity:2,tags:['NEW'],common},{quantity:1,tags:[' '],common},{quantity:101,tags,common}])assert.ok((await send(body)).status>=400);
  assert.equal(await prisma.peripheral.count(),10);assert.equal(await prisma.auditLog.count(),before);
  assert.equal((await send({quantity:1,tags:['VIEWER'],common},'VIEWER')).status,403);
  await prisma.workstation.create({data:{workstationTag:'HOST'}});
  assert.equal((await send({quantity:1,tags:['HOST'],common})).status,409);
  await prisma.appSetting.createMany({data:[{key:'tagPrefixPer',value:'AUTO'},{key:'tagSeparator',value:'/'},{key:'tagSeqLength',value:'5'},{key:'tagSeqStart',value:'20'}]});
  await prisma.workstation.create({data:{workstationTag:'AUTO/00024'}});
  const automatic=await send({quantity:10,common});assert.equal(automatic.status,201);
  const autoItems=(await automatic.json()).items;assert.equal(autoItems.length,10);assert.equal(autoItems[0].peripheralTag,'AUTO/00025');assert.equal(autoItems[9].peripheralTag,'AUTO/00034');
  const next=await send({quantity:1,common});assert.equal((await next.json()).items[0].peripheralTag,'AUTO/00035');
  // Failure after an insertion must roll back every item and its audit log.
  const {createPeripheralBatch}=await import('../src/services/batch-service.js');
  const failing={$transaction:callback=>prisma.$transaction(tx=>callback({...tx,auditLog:{create:()=>{throw Error('Simulated audit failure');}}}))};
  await assert.rejects(createPeripheralBatch(failing,{tags:['ROLLBACK'],common:{category:'Mouse'}},'ADMIN'));
  assert.equal(await prisma.peripheral.count({where:{peripheralTag:'ROLLBACK'}}),0);
 }finally{await new Promise(r=>server.close(r));await prisma.$disconnect();}
});
