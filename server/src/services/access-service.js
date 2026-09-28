import {httpError} from '../middleware/errors.js';
export const permissionNames=['view','add','edit','delete','export','reports'];
export const accessKey=email=>'__access:'+email.toLowerCase();
export function defaults(role){return Object.fromEntries(permissionNames.map(key=>[key,role==='ADMIN'||(['view','export'].includes(key))||(['add','edit'].includes(key)&&role==='EDITOR')]));}
export function validatePermissions(value){
  if(value===null)return null;
  if(!value||typeof value!=='object'||Array.isArray(value)||Object.keys(value).some(k=>!permissionNames.includes(k))||permissionNames.some(k=>typeof value[k]!=='boolean'))throw httpError(400,'Provide all six access permissions as true or false.');
  return Object.fromEntries(permissionNames.map(k=>[k,value[k]]));
}
export async function userAccess(db,user){
  const row=await db.appSetting.findUnique({where:{key:accessKey(user.email)}});
  const customPermissions=row?validatePermissions(JSON.parse(row.value)):null;
  return {customPermissions,permissions:user.role==='ADMIN'?defaults('ADMIN'):customPermissions||defaults(user.role)};
}
export async function saveAccess(db,email,value){
  if(value===undefined)return;
  const permissions=validatePermissions(value),key=accessKey(email);
  if(permissions===null)await db.appSetting.deleteMany({where:{key}});
  else await db.appSetting.upsert({where:{key},create:{key,value:JSON.stringify(permissions)},update:{value:JSON.stringify(permissions)}});
}
export function requirePermission(permission){return(req,res,next)=>{
  if(req.auth?.role==='ADMIN'||req.auth?.permissions?.[permission])return next();
  return next(httpError(403,`Your account does not have ${permission} access. Contact an administrator.`));
};}
