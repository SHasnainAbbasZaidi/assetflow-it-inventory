// AssetFlow | Mahzaidex Tech | Developed by Hasnain Zaidi
import express from 'express';
import {scrapRoutes} from './scrap-service.js';
import multer from 'multer';
import ExcelJS from 'exceljs';
import { httpError } from '../middleware/errors.js';

export function adminTools(prisma, backups) {
  const router = express.Router();
  router.use(async(req,res,next)=>{
    const user = await prisma.appUser.findUnique({where:{email:req.auth.email}});
    if (user?.role !== 'ADMIN' || user.status !== 'ACTIVE') throw httpError(403,'Administrator access required.');
    next();
  });
  router.use('/scrap',scrapRoutes(prisma));
  router.get('/reports',async(req,res)=>{
    const type = req.query.type || 'inventory';
    if (!['inventory','personnel','audit','users','warranty'].includes(type)) throw httpError(400,'Unknown report type.');
    const [ws,per,people] = await prisma.$transaction([
      prisma.workstation.findMany({include:{personnel:true},orderBy:{workstationTag:'asc'}}),
      prisma.peripheral.findMany({include:{personnel:true,workstation:{include:{personnel:true}}},orderBy:{peripheralTag:'asc'}}),
      prisma.personnel.findMany({orderBy:{fullName:'asc'}})
    ]);
    let rows;
    if(type==='audit') {
      const where={};
      if(req.query.from || req.query.to) {
        where.timestamp={};
        for(const [key,bound] of [['from','gte'],['to','lte']]) if(req.query[key]) {
          if(!/^\d{4}-\d{2}-\d{2}$/.test(req.query[key])) throw httpError(400,'Invalid report date.');
          const date=new Date(req.query[key]+(key==='to'?'T23:59:59.999Z':'T00:00:00.000Z'));
          if(Number.isNaN(date.getTime())) throw httpError(400,'Invalid report date.');
          where.timestamp[bound]=date;
        }
      }
      rows=await prisma.auditLog.findMany({where,orderBy:{timestamp:'desc'}});
    } else if(type==='users') rows=await prisma.appUser.findMany({select:{email:true,fullName:true,role:true,status:true,createdAt:true}});
    else {
      rows=[...ws.map(a=>({tag:a.workstationTag,type:'Workstation',description:a.deviceType||'',status:a.status,person:a.personnel?.fullName||a.userName||'',personnelId:a.personnelId||'',department:a.personnel?.department||'',workstation:'',quantity:1,warrantyExpiry:null})),
        ...per.map(a=>{const owner=a.personnel||a.workstation?.personnel;return {tag:a.peripheralTag,type:'Peripheral',description:[a.category,a.modelSpecs].filter(Boolean).join(' / '),status:a.status,person:owner?.fullName||'',personnelId:owner?.id||'',department:owner?.department||'',workstation:a.workstationTag||'',quantity:a.quantity,warrantyExpiry:a.warrantyExpiry};})];
      if(type==='personnel') {
        const assigned=new Set(rows.map(r=>r.personnelId));
        rows=rows.filter(r=>r.personnelId);
        for(const p of people) if(!assigned.has(p.id)) rows.push({tag:'',type:'No assets',description:'',status:'',person:p.fullName,personnelId:p.id,department:p.department||'',workstation:'',quantity:0,warrantyExpiry:null});
        rows.sort((a,b)=>a.person.localeCompare(b.person)||a.tag.localeCompare(b.tag));
      }
      if(type==='warranty') rows=rows.filter(r=>r.warrantyExpiry);
      if(req.query.status) rows=rows.filter(r=>r.status===req.query.status);
      if(req.query.personnelId) rows=rows.filter(r=>r.personnelId===req.query.personnelId);
    }
    const columns=rows.length?Object.keys(rows[0]).filter(k=>k!=='personnelId'):type==='audit'?['logId','timestamp','userEmail','assetTag','actionTaken']:type==='users'?['email','fullName','role','status','createdAt']:['tag','type','description','status','person','department','quantity'];
    if(req.query.format==='xlsx') {
      const book=new ExcelJS.Workbook();book.creator='Mahzaidex Tech / Hasnain Zaidi';
      const sheet=book.addWorksheet('Report');sheet.addRow(columns);sheet.getRow(1).font={bold:true};sheet.views=[{state:'frozen',ySplit:1}];
      for(const row of rows) sheet.addRow(columns.map(k=>row[k]));
      columns.forEach((k,i)=>sheet.getColumn(i+1).width=24);
      res.attachment(`assetflow-${type}.xlsx`).type('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet').send(Buffer.from(await book.xlsx.writeBuffer()));
    } else res.json({type,columns,rows:rows.slice(0,500),total:rows.length,generatedAt:new Date().toISOString()});
  });
  router.post('/super-delete',async(req,res)=>{
    const {kind,tag,confirmation}=req.body;
    if(!['workstation','peripheral'].includes(kind)||typeof tag!=='string'||!tag||confirmation!==tag) throw httpError(400,'Select an asset and type its exact tag to confirm.');
    await prisma.$transaction(async tx=>{
      if(kind==='workstation') {
        // Keep attached peripherals; return inherited assignments to store.
        await tx.peripheral.updateMany({where:{workstationTag:tag,personnelId:null,status:'ASSIGNED'},data:{status:'IN_STORE'}});
        await tx.peripheral.updateMany({where:{workstationTag:tag},data:{workstationTag:null}});
        await tx.workstation.delete({where:{workstationTag:tag}});
      } else await tx.peripheral.delete({where:{peripheralTag:tag}});
    });
    // Intentionally silent: no audit entry or notification for this administrator action.
    res.status(204).end();
  });
  router.get('/backups',async(req,res)=>res.json({automatic:await backups.list('automatic'),manual:await backups.list('manual'),excel:await backups.list('excel'),schedule:'Daily while the server is running',...backups.status()}));
  router.post('/backups',async(req,res)=>res.status(201).json(await backups.manual()));
  router.get('/backups/:kind/:name',async(req,res)=>res.attachment(req.params.name).send(await backups.read(req.params.kind,req.params.name)));
  router.post('/restore',multer({storage:multer.memoryStorage(),limits:{fileSize:100*1024*1024}}).single('file'),async(req,res)=>{
    if(req.body.confirmation!=='RESTORE') throw httpError(400,'Type RESTORE to confirm replacement of the current application state.');
    let buffer=req.file?.buffer;
    if(!buffer) buffer=await backups.read(req.body.kind,req.body.name);
    let input;try{input=JSON.parse(buffer.toString('utf8'));}catch{throw httpError(400,'Invalid backup file.');}
    res.json(await backups.restore(input));
  });
  return router;
}
