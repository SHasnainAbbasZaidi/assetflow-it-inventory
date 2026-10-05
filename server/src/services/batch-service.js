import crypto from 'node:crypto';
import { httpError } from '../middleware/errors.js';

// Each physical item and its audit entry commit together; a conflict rolls back the batch.
export async function createPeripheralBatch(prisma, { tags, quantity, common }, email) {
  if (tags && new Set(tags).size !== tags.length) throw httpError(400, 'Every item must have a unique tag number.');
  return prisma.$transaction(async tx => {
    if(!tags){
      const settings=Object.fromEntries((await tx.appSetting.findMany({where:{key:{in:['tagPrefixPer','tagSeparator','tagSeqLength','tagSeqStart']}}})).map(row=>[row.key,row.value]));
      const stem=(settings.tagPrefixPer||'PER')+(settings.tagSeparator??'-');
      const digits=Math.max(1,Math.min(10,Math.floor(Number(settings.tagSeqLength)||4)));
      let next=Math.max(1,Math.floor(Number(settings.tagSeqStart)||2001));
      const existing=[...(await tx.peripheral.findMany({select:{peripheralTag:true}})).map(a=>a.peripheralTag),...(await tx.workstation.findMany({select:{workstationTag:true}})).map(a=>a.workstationTag)];
      for(const tag of existing){const suffix=tag.startsWith(stem)?tag.slice(stem.length):'';if(/^[0-9]+$/.test(suffix))next=Math.max(next,Number(suffix)+1);}
      if(!Number.isSafeInteger(next+quantity))throw httpError(400,'Tag sequence is too large. Choose another prefix in Settings.');
      tags=Array.from({length:quantity},(_,i)=>stem+String(next+i).padStart(digits,'0'));
    }
    const conflicts = [
      ...await tx.peripheral.findMany({where:{peripheralTag:{in:tags}},select:{peripheralTag:true}}),
      ...await tx.workstation.findMany({where:{workstationTag:{in:tags}},select:{workstationTag:true}}),
    ];
    if(conflicts.length)throw httpError(409,'Tag numbers already exist: '+conflicts.map(a=>a.peripheralTag||a.workstationTag).join(', '));
    if(common.personnelId && common.workstationTag)throw httpError(400,'Choose a person or workstation, not both.');
    const person=common.personnelId?await tx.personnel.findUnique({where:{id:common.personnelId}}):null;
    const workstation=common.workstationTag?await tx.workstation.findUnique({where:{workstationTag:common.workstationTag}}):null;
    if(common.personnelId && !person)throw httpError(409,'Referenced person does not exist.');
    if(common.workstationTag && !workstation)throw httpError(409,'Referenced workstation does not exist.');
    if(workstation && ['RETIRED','SCRAPPED','OUT_OF_ORDER'].includes(workstation.status))throw httpError(409,'Choose a workstation in service.');
    const items=[];
    for(const tag of tags){
      const item=await tx.peripheral.create({data:{...common,peripheralTag:tag,quantity:1,personnelId:common.personnelId||null,workstationTag:common.workstationTag||null,status:person||workstation?'ASSIGNED':'IN_STORE'}});
      await tx.auditLog.create({data:{logId:crypto.randomUUID(),timestamp:new Date(),userEmail:email,assetTag:tag,actionTaken:'Created peripheral in batch of '+tags.length+'; assigned to '+(person?.fullName||workstation?.workstationTag||'Unassigned')}});
      items.push(item);
    }
    return {count:items.length,items};
  },{timeout:15000});
}
