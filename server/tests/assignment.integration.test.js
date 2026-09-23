import { test } from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync, backup } from 'node:sqlite';
import fs from 'node:fs/promises';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { PrismaClient } from '@prisma/client';
import { assignAsset, assignmentState } from '../src/services/assignment-service.js';

test('safe additive migration and assignment API service on an isolated database copy', async () => {
  const folder=await fs.mkdtemp(path.resolve('tests/assignment-test-'));
  const dbPath=path.join(folder,'test.db');
  const source=new DatabaseSync(path.resolve('prisma/dev.db'),{readOnly:true});
  await backup(source,dbPath);source.close();
  const before=new DatabaseSync(dbPath);const counts=before.prepare('SELECT COUNT(*) n FROM workstations').get();before.close();
  const url='file:'+dbPath.replaceAll('\\','/');
  const run=spawnSync(process.execPath,['scripts/migrate-direct-assignment.js'],{env:{...process.env,DATABASE_URL:url},encoding:'utf8'});
  assert.equal(run.status,0,run.stderr);console.log(run.stdout);
  const again=spawnSync(process.execPath,['scripts/migrate-direct-assignment.js'],{env:{...process.env,DATABASE_URL:url},encoding:'utf8'});
  assert.equal(again.status,0,again.stderr);
  const check=new DatabaseSync(dbPath);assert.equal(check.prepare('SELECT COUNT(*) n FROM workstations').get().n,counts.n);check.close();
  const prisma=new PrismaClient({datasources:{db:{url}}});
  const id='test-'+Date.now();
  try {
    await prisma.personnel.create({data:{id:id+'a',fullName:'Test Person A'}});
    await prisma.personnel.create({data:{id:id+'b',fullName:'Test Person B'}});
    const ws=await prisma.workstation.create({data:{workstationTag:id,status:'IN_STORE'}});
    const initial=assignmentState(ws);
    const assigned=await assignAsset(prisma,'workstation',id,{personnelId:id+'a',expectedState:initial},'test');
    assert.equal(assigned.item.personnelId,id+'a');
    const retry=await assignAsset(prisma,'workstation',id,{personnelId:id+'a',expectedState:initial},'test');
    assert.equal(retry.unchanged,true);
    assert.equal(await prisma.auditLog.count({where:{assetTag:id}}),1);
    await assert.rejects(assignAsset(prisma,'workstation',id,{personnelId:id+'b',expectedState:initial,allowReassign:true},'test'),{code:'STALE_ASSIGNMENT'});
    await assert.rejects(assignAsset(prisma,'workstation',id,{personnelId:id+'b',expectedState:assignmentState(assigned.item)},'test'),{code:'CONFIRM_REASSIGN'});
    const peripheral=await prisma.peripheral.create({data:{peripheralTag:id+'p',workstationTag:id,status:'IN_STORE'},include:{workstation:true}});
    const direct=await assignAsset(prisma,'peripheral',id+'p',{personnelId:id+'b',expectedState:assignmentState(peripheral),allowReassign:true},'test');
    assert.equal(direct.item.personnelId,id+'b');assert.equal(direct.item.workstationTag,null);
    process.env.NODE_ENV='test';process.env.DATABASE_URL=url;
    const {app}=await import('../src/server.js');
    const {prisma:apiPrisma}=await import('../src/prisma.js');
    const jwt=(await import('jsonwebtoken')).default;
    const server=app.listen(0,'127.0.0.1');await new Promise(resolve=>server.once('listening',resolve));
    try {
      const base=`http://127.0.0.1:${server.address().port}`;
      const token=role=>jwt.sign({email:'test',role},process.env.JWT_SECRET || 'assetflow-super-secret-production-key-2026');
      const endpoint=`${base}/api/assets/workstation/${id}/assign`;
      assert.equal((await fetch(endpoint,{method:'POST',headers:{'Content-Type':'application/json'},body:'{}'})).status,401);
      assert.equal((await fetch(endpoint,{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+token('VIEWER')},body:'{}'})).status,403);
      const headers={Authorization:'Bearer '+token('ADMIN')};
      const people=await (await fetch(`${base}/api/personnel/${id}b`,{headers})).json();
      assert.equal(people.peripherals[0].peripheralTag,id+'p');
      const lookup=await (await fetch(`${base}/api/assets/lookup/${id}p`,{headers})).json();
      assert.equal(lookup.data.personnel.id,id+'b');assert.ok(lookup.data.assignmentState);
    } finally {await new Promise(resolve=>server.close(resolve));await apiPrisma.$disconnect();}
    await prisma.peripheral.update({where:{peripheralTag:id+'p'},data:{status:'RETIRED'}});
    await assert.rejects(assignAsset(prisma,'peripheral',id+'p',{personnelId:id+'a',expectedState:'x'},'test'),{status:409});
    console.log('Migration idempotency, counts, direct assignment, duplicate retry, stale state, reassignment and retired-state checks passed.');
  } finally {await prisma.$disconnect();}
});
