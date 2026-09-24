import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {DatabaseSync} from 'node:sqlite';
import {PrismaClient} from '@prisma/client';
import ExcelJS from 'exceljs';
import {exportWorkbook,importWorkbook} from '../src/services/excel-service.js';
import {snapshot,stateWorkbook,createBackupService} from '../src/services/backup-service.js';
import {hardwareGroup,inventoryGroups} from '../src/services/hardware-workbook.js';
import vm from 'node:vm';

test('category Excel and full-state backups preserve hardware, ownership and legacy compatibility',async()=>{
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'assetflow-category-'));const clients=[];
 try{
  for(const name of ['source','target']){const file=path.join(root,name+'.db'),db=new DatabaseSync(file);db.exec(await fs.readFile('prisma/initial-schema.sql','utf8'));db.close();clients.push(new PrismaClient({datasources:{db:{url:'file:'+file.replaceAll('\\','/')}}}));}
  const [source,target]=clients;
  await source.appUser.create({data:{email:'admin@test',fullName:'Admin',role:'ADMIN',passwordHash:'test-only-hash'}});
  await source.personnel.create({data:{id:'person',fullName:'Equipment owner',department:'IT',contactEmail:'owner@test'}});
  await source.workstation.create({data:{workstationTag:'WS-1',personnelId:'person',deviceType:'Mini PC',processorGen:'i7',ram:'32 GB',hdd:'2 TB',customFields:'{"room":"Studio"}',status:'ASSIGNED'}});
  for(const [tag,category] of [['PER-1','Keyboard'],['DEV-1','Printer'],['CMP-1','GPU'],['MB-1','Motherboard']])await source.peripheral.create({data:{peripheralTag:tag,category,personnelId:tag==='DEV-1'?'person':null,workstationTag:tag==='PER-1'?'WS-1':null,quantity:2,modelSpecs:'Model X',gpuSpecs:'8 GB',customFields:'{"color":"blue"}',purchaseDate:new Date('2025-03-01')}});
  const bytes=await exportWorkbook(source),book=new ExcelJS.Workbook();await book.xlsx.load(bytes);
  assert.deepEqual(book.worksheets.map(s=>s.name),['Workstations','Peripherals','Devices','Components','Personnel','Users','Audit Logs']);
  assert.equal(book.getWorksheet('Workstations').rowCount,3);assert.equal(book.getWorksheet('Devices').getCell('B2').value,'DEV-1');
  assert.ok(!JSON.stringify(book.worksheets.map(s=>s.getSheetValues())).includes('test-only-hash'));
  const result=await importWorkbook(bytes,target,{name:'Admin',email:'admin@test',role:'ADMIN'});assert.equal(result.errors.length,0);
  for(const [model,key] of [['workstation','workstationTag'],['peripheral','peripheralTag'],['personnel','id']])assert.deepEqual(await target[model].findMany({orderBy:{[key]:'asc'}}),await source[model].findMany({orderBy:{[key]:'asc'}}));
  const before=await snapshot(target);book.getWorksheet('Devices').getCell('D2').value='missing-person';book.getWorksheet('Personnel').getCell('B2').value='Changed name';
  await assert.rejects(importWorkbook(await book.xlsx.writeBuffer(),target));assert.equal((await snapshot(target)).checksum,before.checksum);
  const full=await snapshot(source);assert.deepEqual(Object.keys(full.inventoryGroups),['Workstations','Peripherals','Devices','Components']);
  const reference=new ExcelJS.Workbook();await reference.xlsx.load(await stateWorkbook(full));assert.equal(reference.getWorksheet('Components').getCell('B2').value,'CMP-1');
  await importWorkbook(await stateWorkbook(full),target,{name:'Admin',email:'admin@test',role:'ADMIN'});
  assert.equal((await snapshot(target)).checksum,before.checksum);
  await target.workstation.update({where:{workstationTag:'WS-1'},data:{processorGen:'changed'}});
  await createBackupService(target,root).restore(full);assert.equal((await snapshot(target)).checksum,full.checksum);assert.deepEqual(inventoryGroups((await snapshot(target)).tables),full.inventoryGroups);
  // Previous full-state files have no category index and must still restore.
  const legacy={...full};delete legacy.inventoryGroups;await createBackupService(target,root).restore(legacy);assert.equal((await snapshot(target)).checksum,full.checksum);
  const context=vm.createContext({});vm.runInContext(await fs.readFile('public/js/hardware-groups.js','utf8'),context);
  for(const category of ['Motherboard','Mini PC','Keyboard','Printer','VR','SSD','GPU','Unknown'])assert.equal(hardwareGroup(category),context.HardwareGroups.classify(category));
 }finally{for(const client of clients)await client.$disconnect();await fs.rm(root,{recursive:true,force:true});}
});
