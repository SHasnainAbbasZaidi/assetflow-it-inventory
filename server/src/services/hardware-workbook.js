import ExcelJS from 'exceljs';
import {Prisma} from '@prisma/client';
import {registerScrapped} from './scrap-service.js';

export const hardwareGroups=['Workstations','Peripherals','Devices','Components'];
export function hardwareGroup(category,kind='peripheral') {
 if(kind==='workstation')return 'Workstations';
 const c=String(category||'').toLowerCase().replace(/[-_/]/g,' ');
 if(/\b(motherboard|mainboard|laptop|desktop|computer|workstation|pc|aio)\b|all in one/.test(c))return 'Workstations';
 if(/\b(ram|ssd|hdd|gpu|cpu|processor|memory|storage|graphics|psu|power supply|cooler|internal|component)\b/.test(c))return 'Components';
 if(/\b(printer|scanner|network|networking|router|switch|firewall|access point|modem|vr|webcam|camera|projector|server|nas|tablet|mobile)\b/.test(c))return 'Devices';
 return 'Peripherals';
}
const fieldLabels={userName:'User Name',personnelId:'Personnel ID',deviceType:'Device Type',motherboard:'Motherboard',processorGen:'Processor & Gen',ram:'RAM',ssd:'SSD',hdd:'HDD',gpu:'GPU',status:'Status',assignedDate:'Assigned Date',pdfFile:'PDF File',notes:'Notes',customFields:'Custom Fields',category:'Category',modelSpecs:'Model Specs',workstationTag:'Linked Workstation Tag',purchaseDate:'Purchase Date',warrantyExpiry:'Warranty Expiry',brandManufacturer:'Brand / Manufacturer',quantity:'Quantity',storageCapacity:'Storage Capacity',gpuSpecs:'GPU Specs'};
export const hardwareHeaders=['Record Type','Tag',...Object.values(fieldLabels)];
const modelFields=name=>Prisma.dmmf.datamodel.models.find(m=>m.name===name).fields.filter(f=>f.kind==='scalar');
const ancillary={Personnel:'Personnel',Users:'AppUser','Audit Logs':'AuditLog'};
export function hardwareRows(tables){return [...tables.workstation.map(item=>({kind:'workstation',tag:item.workstationTag,item})),...tables.peripheral.map(item=>({kind:'peripheral',tag:item.peripheralTag,item}))].map(row=>({...row,group:hardwareGroup(row.item.category,row.kind)}));}
export function inventoryGroups(tables){const rows=hardwareRows(tables);return Object.fromEntries(hardwareGroups.map(group=>[group,rows.filter(r=>r.group===group).map(r=>({recordType:r.kind,tag:r.tag}))]));}
export function addHardwareSheets(book,tables) {
 const rows=hardwareRows(tables);
 for(const group of hardwareGroups){
  const sheet=book.addWorksheet(group);sheet.addRow(hardwareHeaders);
  for(const r of rows.filter(r=>r.group===group))sheet.addRow([r.kind,r.tag,...Object.keys(fieldLabels).map(key=>key==='workstationTag'&&r.kind==='workstation'?null:r.item[key]??null)]);
  styleSheet(sheet);
  sheet.getColumn(1).hidden=true; // Preserve import identity without cluttering the inventory view.
 }
}
export function styleSheet(sheet){
 sheet.views=[{state:'frozen',ySplit:1}];sheet.autoFilter={from:'A1',to:{row:1,column:sheet.columnCount}};
 sheet.getRow(1).font={bold:true,color:{argb:'FFFFFFFF'}};sheet.getRow(1).fill={type:'pattern',pattern:'solid',fgColor:{argb:'FF25334D'}};sheet.getRow(1).height=28;
 sheet.columns.forEach(c=>{c.width=23;});sheet.eachRow((row,n)=>{if(n>1)row.eachCell(cell=>{cell.alignment={vertical:'top',wrapText:true};if(cell.value instanceof Date)cell.numFmt='yyyy-mm-dd hh:mm';});});
}
export async function categoryWorkbook(tables){
 const book=new ExcelJS.Workbook();book.creator='Mahzaidex Tech / Hasnain Zaidi';addHardwareSheets(book,tables);
 for(const [sheetName,model] of Object.entries(ancillary)){
  const name=model[0].toLowerCase()+model.slice(1),fields=modelFields(model).filter(f=>f.name!=='passwordHash').map(f=>f.name);
  const sheet=book.addWorksheet(sheetName);sheet.addRow(fields);for(const row of tables[name])sheet.addRow(fields.map(key=>row[key]));styleSheet(sheet);
 }
 return book.xlsx.writeBuffer();
}
function cellValue(value){if(value==null||value==='')return null;if(typeof value==='object'&&!(value instanceof Date))throw Error('Formulas and rich-text cells are not supported in imports. Paste plain values.');return value;}
function scalar(field,value){value=cellValue(value);if(value===null){if(field.isRequired&&!field.hasDefaultValue)throw Error(field.name+' is required.');return null;}if(field.type==='DateTime'){const date=value instanceof Date?value:new Date(value);if(Number.isNaN(date.getTime()))throw Error('Invalid '+field.name);return date;}if(field.type==='Int'){const n=Number(value);if(!Number.isInteger(n)||n<0)throw Error('Invalid '+field.name);return n;}return String(value);}
function readRows(sheet,headers){if(!sheet)throw Error('A required workbook sheet is missing.');if(headers.some((h,i)=>sheet.getRow(1).getCell(i+1).value!==h))throw Error('Invalid headers in '+sheet.name);const rows=[];sheet.eachRow((row,n)=>{if(n>1)rows.push({number:n,values:headers.map((_,i)=>cellValue(row.getCell(i+1).value))});});return rows;}
/** Category-format imports validate and commit atomically. Legacy imports remain supported separately. */
export async function importCategoryWorkbook(book,prisma,operator){
 const parsed=[],people=[],users=[],logs=[],seen=new Set();
 for(const group of hardwareGroups)for(const row of readRows(book.getWorksheet(group),hardwareHeaders)){
  const [kind,tag,...values]=row.values;if(!['workstation','peripheral'].includes(kind)||!String(tag||'').trim())throw Error(`${group} row ${row.number}: Record Type and Tag are required.`);
  const key=kind+':'+tag;if(seen.has(key))throw Error('Duplicate record '+tag);seen.add(key);
  const raw=Object.fromEntries(Object.keys(fieldLabels).map((key,i)=>[key,values[i]]));
  if(hardwareGroup(raw.category,kind)!==group)throw Error(`Tag ${tag} belongs in ${hardwareGroup(raw.category,kind)}.`);
  const model=kind==='workstation'?'Workstation':'Peripheral',id=kind==='workstation'?'workstationTag':'peripheralTag';
  const data={[id]:String(tag)};for(const field of modelFields(model).filter(f=>f.name!==id))data[field.name]=scalar(field,raw[field.name]);
  data.status=String(data.status||'IN_STORE').toUpperCase().replaceAll(' ','_');if(!['IN_STORE','ASSIGNED','OUT_OF_ORDER','RETIRED','SCRAPPED'].includes(data.status))throw Error('Invalid status for '+tag);
  if(kind==='peripheral'){data.quantity??=1;if(data.workstationTag&&data.personnelId)throw Error('Choose one assignment for '+tag);}
  if(data.customFields){let cf;try{cf=JSON.parse(data.customFields);}catch{throw Error('Invalid custom-field JSON for '+tag);}if(!cf||Array.isArray(cf)||typeof cf!=='object')throw Error('Custom fields must be a JSON object.');}
  parsed.push({kind,id,tag:String(tag),data});
 }
 for(const [sheetName,model] of Object.entries(ancillary)){
  const fields=modelFields(model).filter(f=>f.name!=='passwordHash'),target=sheetName==='Personnel'?people:sheetName==='Users'?users:logs;
  for(const row of readRows(book.getWorksheet(sheetName),fields.map(f=>f.name))){const data={};fields.forEach((f,i)=>{const value=scalar(f,row.values[i]);if(value!==null||!f.hasDefaultValue)data[f.name]=value;});target.push(data);}
 }
 for(const user of users)if(!['ADMIN','EDITOR','VIEWER'].includes(user.role)||!['ACTIVE','INACTIVE'].includes(user.status))throw Error('Invalid user role or status.');
 return prisma.$transaction(async tx=>{
  const result={inserted:0,updated:0,skipped:0,errors:[]};
  async function upsert(model,key,data){const exists=await tx[model].findUnique({where:{[key]:data[key]}});await tx[model].upsert({where:{[key]:data[key]},create:data,update:data});result[exists?'updated':'inserted']++;}
  for(const p of people)await upsert('personnel','id',p);
  for(const user of users)await upsert('appUser','email',user);
  for(const r of parsed.sort((a,b)=>a.kind===b.kind?0:a.kind==='workstation'?-1:1)){
   const old=await tx[r.kind].findUnique({where:{[r.id]:r.tag}});
   if(old?.status==='SCRAPPED'){result.skipped++;continue;}
   await upsert(r.kind,r.id,r.data);
  }
  // Register only after all links and item rows have been restored.
  for(const r of parsed.filter(r=>r.data.status==='SCRAPPED')){if(!operator)throw Error('A verified operator is required for scrapped imports.');await registerScrapped(tx,r.kind,r.tag,operator);}
  for(const log of logs){if(await tx.auditLog.findUnique({where:{logId:log.logId}})){result.skipped++;continue;}await tx.auditLog.create({data:log});result.inserted++;}
  return result;
 },{timeout:60000});
}
