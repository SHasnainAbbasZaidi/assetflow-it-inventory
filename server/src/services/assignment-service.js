import crypto from 'node:crypto';
import { httpError } from '../middleware/errors.js';
export async function assignAsset(prisma, kind, tag, request, email) {
  if (!['workstation', 'peripheral'].includes(kind)) throw httpError(400,'Unsupported asset type.');
  if (!request || typeof request.personnelId !== 'string' || typeof request.expectedState !== 'string') throw httpError(400,'Person and scanned asset state are required.');
  return prisma.$transaction(async tx => {
    const model=kind==='workstation'?tx.workstation:tx.peripheral;
    const key=kind==='workstation'?'workstationTag':'peripheralTag';
    const item=await model.findUnique({where:{[key]:tag},include:kind==='workstation'?{personnel:true,peripherals:true}:{personnel:true,workstation:{include:{personnel:true}}}});
    if(!item)throw httpError(404,'Asset not found.');
    const person=await tx.personnel.findUnique({where:{id:request.personnelId}});
    if(!person)throw httpError(404,'Person no longer exists. Select another person.');
    const owner=item.personnelId || item.workstation?.personnelId || null;
    if(['RETIRED','OUT_OF_ORDER','SCRAPPED'].includes(item.status))throw httpError(409,'Restore this item to service before assigning it.');
    if(owner===person.id && item.status==='ASSIGNED')return {item,person,unchanged:true};
    if(assignmentState(item)!==request.expectedState)throw httpError(409,'Assignment changed since scanning. Scan again before assigning.','STALE_ASSIGNMENT');
    if((owner || item.status==='ASSIGNED' || (kind==='peripheral' && item.workstationTag)) && request.allowReassign!==true)throw httpError(409,'Confirm reassignment before replacing the current owner.','CONFIRM_REASSIGN');
    const patch=kind==='workstation'?{personnelId:person.id,userName:person.fullName,assignedDate:new Date(),status:'ASSIGNED'}:{personnelId:person.id,workstationTag:null,status:'ASSIGNED'};
    const updated=await model.update({where:{[key]:tag},data:patch,include:kind==='workstation'?{personnel:true}:{personnel:true,workstation:true}});
    await tx.auditLog.create({data:{logId:crypto.randomUUID(),timestamp:new Date(),userEmail:email,assetTag:tag,actionTaken:`Assigned ${kind} to ${person.fullName}${owner ? ' (reassigned)' : ''}${kind==='peripheral'&&item.workstationTag?' — detached from '+item.workstationTag:''}`}});
    return {item:updated,person,unchanged:false};
  });
}
export function assignmentState(item) {
  return JSON.stringify([item.status,item.personnelId||null,item.workstationTag||null,item.workstation?.personnelId||null,item.userName||null]);
}
