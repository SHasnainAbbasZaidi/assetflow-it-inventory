// Mahzaidex Tech — transactional scrap register and immutable report snapshots.
import crypto from 'node:crypto';
import express from 'express';
import ExcelJS from 'exceljs';
import {httpError} from '../middleware/errors.js';
const hash=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
const prefix='__scrap-report:';
// Called in the same transaction as any non-report route that marks an item scrapped.
export async function registerScrapped(tx,kind,tag,operator,{legacy=false}={}) {
 const entries=await tx.appSetting.findMany({where:{key:{startsWith:prefix}}});
 if(entries.some(e=>JSON.parse(e.value).rows.some(r=>r.tag===tag&&r.type===(kind==='workstation'?'Workstation':'Peripheral'))))return;
 const ws=kind==='workstation';
 const item=ws?await tx.workstation.findUnique({where:{workstationTag:tag},include:{personnel:true,peripherals:true}}):await tx.peripheral.findUnique({where:{peripheralTag:tag},include:{personnel:true,workstation:{include:{personnel:true}}}});
 if(!item||item.status!=='SCRAPPED')return;
 if(!legacy&&ws&&item.peripherals.length)throw httpError(409,'Detach attached items or scrap them together using Scrap Items Report.');
 const owner=item.personnel||item.workstation?.personnel;
 const {personnel,peripherals,workstation,...details}=item;
 const date=new Date().toISOString(),id=crypto.randomUUID();
 const report={id,date,operator:operator||{name:'Unknown (legacy record)',email:'Not recorded',role:'Unknown'},source:legacy?'Historical reconciliation; original scrap date/operator were not recorded.':'Inventory status/import',tags:[tag],rows:[{tag,type:ws?'Workstation':'Peripheral',description:ws?item.deviceType||'':item.category||'',previousStatus:legacy?'Not recorded':'Imported/status update',status:'SCRAPPED',person:owner?.fullName||item.userName||'',department:owner?.department||'',quantity:ws?1:item.quantity,scrapDate:legacy?'Not recorded':date,details}]};
 await tx.appSetting.create({data:{key:prefix+id,value:JSON.stringify(report)}});
 if(!legacy){
  if(ws)await tx.workstation.update({where:{workstationTag:tag},data:{personnelId:null,userName:null,assignedDate:null}});
  else await tx.peripheral.update({where:{peripheralTag:tag},data:{personnelId:null,workstationTag:null}});
  await tx.auditLog.create({data:{logId:crypto.randomUUID(),timestamp:new Date(date),userEmail:operator?.email||'System',assetTag:tag,actionTaken:'Scrapped item. Report '+id}});
 }
}
export async function reconcileScrapped(prisma) {
 await prisma.$transaction(async tx=>{
  for(const item of await tx.workstation.findMany({where:{status:'SCRAPPED'}}))await registerScrapped(tx,'workstation',item.workstationTag,null,{legacy:true});
  for(const item of await tx.peripheral.findMany({where:{status:'SCRAPPED'}}))await registerScrapped(tx,'peripheral',item.peripheralTag,null,{legacy:true});
 },{timeout:30000});
}
export function parseTags(value){if(typeof value!=='string'||value.length>20000)throw httpError(400,'Enter tag numbers separated by spaces, commas or new lines.');const tags=[...new Set(value.split(/[\s,;]+/).filter(Boolean))];if(!tags.length||tags.length>200)throw httpError(400,'Enter between 1 and 200 unique tags.');return tags;}
async function preview(tx,tags){
 const rows=[];
 for(const tag of tags){
  const ws=await tx.workstation.findUnique({where:{workstationTag:tag},include:{personnel:true,peripherals:true}});
  const per=await tx.peripheral.findUnique({where:{peripheralTag:tag},include:{personnel:true,workstation:{include:{personnel:true}}}});
  if(!ws&&!per)throw httpError(404,`Tag ${tag} was not found. No items were changed.`);
  if(ws&&per)throw httpError(409,`Tag ${tag} is ambiguous. Give the workstation and peripheral distinct tags first.`);
  const item=ws||per;if(item.status==='SCRAPPED')throw httpError(409,`Tag ${tag} is already scrapped. Reprint its existing scrap report.`);
  if(ws&&ws.peripherals.some(p=>!tags.includes(p.peripheralTag)))throw httpError(409,`Include all peripherals attached to ${tag}, or detach them before scrapping this workstation.`);
  const owner=item.personnel||per?.workstation?.personnel;
  const {personnel,peripherals,workstation,...details}=item;
  rows.push({tag,type:ws?'Workstation':'Peripheral',description:ws?ws.deviceType||'': [per.category,per.modelSpecs].filter(Boolean).join(' / '),previousStatus:item.status,status:'SCRAPPED',person:owner?.fullName||ws?.userName||'',department:owner?.department||'',quantity:ws?1:per.quantity,details});
 }
 return {rows,fingerprint:hash(rows)};
}
export function scrapRoutes(prisma){
 const router=express.Router();
 router.post('/preview',async(req,res)=>res.json(await prisma.$transaction(tx=>preview(tx,parseTags(req.body.tags)))));
 router.post('/',async(req,res)=>{
  const tags=parseTags(req.body.tags),{requestId,fingerprint}=req.body;
  if(!/^[a-f0-9-]{36}$/.test(requestId||'')||typeof fingerprint!=='string')throw httpError(400,'Preview the selected tags before confirming.');
  const result=await prisma.$transaction(async tx=>{
   const old=await tx.appSetting.findUnique({where:{key:prefix+requestId}});
   if(old){const report=JSON.parse(old.value);if(report.operator.email!==req.auth.email||JSON.stringify(report.tags)!==JSON.stringify(tags))throw httpError(409,'This report reference is already in use.');return report;}
   const checked=await preview(tx,tags);if(checked.fingerprint!==fingerprint)throw httpError(409,'Item details changed. Preview again before scrapping.');
   const operator=await tx.appUser.findUnique({where:{email:req.auth.email}});
   const report={id:requestId,date:new Date().toISOString(),operator:{name:operator.fullName,email:operator.email,role:operator.role},tags,rows:checked.rows};
   report.rows.forEach(row=>row.scrapDate=report.date);
   for(const row of report.rows){
    if(row.type==='Workstation')await tx.workstation.update({where:{workstationTag:row.tag},data:{status:'SCRAPPED',personnelId:null,userName:null,assignedDate:null}});
    else await tx.peripheral.update({where:{peripheralTag:row.tag},data:{status:'SCRAPPED',personnelId:null,workstationTag:null}});
    await tx.auditLog.create({data:{logId:crypto.randomUUID(),timestamp:new Date(report.date),userEmail:operator.email,assetTag:row.tag,actionTaken:'Scrapped item. Report '+report.id}});
   }
   await tx.appSetting.create({data:{key:prefix+report.id,value:JSON.stringify(report)}});return report;
  },{timeout:30000});res.json(result);
 });
 router.get('/',async(req,res)=>{await reconcileScrapped(prisma);const rows=await prisma.appSetting.findMany({where:{key:{startsWith:prefix}},orderBy:{updatedAt:'desc'},take:100});res.json(rows.map(r=>{const v=JSON.parse(r.value);return {id:v.id,date:v.date,operator:v.operator,count:v.rows.length};}));});
 router.get('/:id',async(req,res)=>{
  if(!/^[a-f0-9-]{36}$/.test(req.params.id))throw httpError(400,'Invalid report reference.');
  const entry=await prisma.appSetting.findUnique({where:{key:prefix+req.params.id}});if(!entry)throw httpError(404,'Scrap report not found.');const report=JSON.parse(entry.value);
  if(req.query.format==='xlsx'){
   const book=new ExcelJS.Workbook();book.creator='Mahzaidex Tech / Hasnain Zaidi';const sheet=book.addWorksheet('Scrap Items Report');
   sheet.addRow(['Scrap Items Report',report.id]);sheet.addRow(['Report date',report.date]);sheet.addRow(['Operator',report.operator.name,report.operator.email,report.operator.role]);sheet.addRow([]);
   sheet.addRow(['Tag','Type','Description','Previous status','Status','Previous owner','Department','Quantity','Item details','Scrap date']);
   report.rows.forEach(r=>sheet.addRow([r.tag,r.type,r.description,r.previousStatus,r.status,r.person,r.department,r.quantity,JSON.stringify(r.details),r.scrapDate||report.date]));
   sheet.getRow(5).font={bold:true};sheet.columns.forEach((c,i)=>{c.width=i===8?70:22;c.alignment={wrapText:true,vertical:'top'};});sheet.pageSetup={paperSize:9,orientation:'landscape',fitToPage:true,fitToWidth:1,fitToHeight:0,printTitlesRow:'1:5'};
   return res.attachment(`scrap-report-${report.id}.xlsx`).send(Buffer.from(await book.xlsx.writeBuffer()));
  }
  res.json(report);
 });
 return router;
}
