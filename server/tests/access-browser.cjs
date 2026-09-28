const {chromium}=require('../../.build-tools/node_modules/playwright');
const {DatabaseSync}=require('node:sqlite');
const fs=require('node:fs/promises'),path=require('node:path'),assert=require('node:assert/strict');
(async()=>{
 const folder=await fs.mkdtemp(path.resolve('../.build-tools/access-ui-')),file=path.join(folder,'test.db');
 const db=new DatabaseSync(file);db.exec(await fs.readFile('prisma/initial-schema.sql','utf8'));db.close();
 process.env.NODE_ENV='test';process.env.DATABASE_URL='file:'+file.replaceAll('\\','/');process.env.JWT_SECRET='isolated-access-browser-secret-123456789';process.env.BACKUP_ROOT=folder;
 const {app}=await import('../src/server.js'),{prisma}=await import('../src/prisma.js'),{default:jwt}=await import('jsonwebtoken');
 for(const role of ['ADMIN','EDITOR'])await prisma.appUser.create({data:{email:role.toLowerCase()+'@example.invalid',fullName:role,role}});
 await prisma.workstation.create({data:{workstationTag:'RETIRED-1',status:'RETIRED'}});
 await prisma.workstation.create({data:{workstationTag:'ACTIVE-1',status:'IN_STORE'}});
 await prisma.personnel.create({data:{id:'person-1',fullName:'Assignment test'}});
 const server=app.listen(0,'127.0.0.1');await new Promise(r=>server.once('listening',r));
 const base='http://127.0.0.1:'+server.address().port,browser=await chromium.launch({headless:true});
 try {
  for(const role of ['ADMIN','EDITOR']){
   const page=await browser.newPage({viewport:{width:390,height:844}}),errors=[];
   page.setDefaultTimeout(10000);page.on('response',async r=>{if(r.status()>=400&&r.url().includes('/api/'))console.error(r.status(),await r.text());});
   page.on('pageerror',e=>errors.push(e.message));
   await page.addInitScript(({token,user})=>{localStorage.setItem('assetflow_token',token);localStorage.setItem('assetflow_user',JSON.stringify(user));},{token:jwt.sign({email:role.toLowerCase()+'@example.invalid'},process.env.JWT_SECRET),user:{role,email:role.toLowerCase()+'@example.invalid'}});
   await page.route('**/*',route=>new URL(route.request().url()).hostname==='127.0.0.1'?route.continue():route.abort());
   await page.goto(base,{waitUntil:'domcontentloaded'});await page.waitForFunction(()=>typeof currentUser!=='undefined'&&currentUser.permissions&&data.workstations.length===2);
   await page.evaluate(()=>lookupAsset('RETIRED-1'));await page.locator('#lookupModal.active').waitFor();
   assert.equal(await page.getByRole('button',{name:'Restore Asset',exact:true}).count(),role==='ADMIN'?1:0);
   await page.evaluate(()=>closeModal('lookupModal'));
   if(role==='ADMIN'){
    await page.evaluate(()=>switchTab('workstations'));
    await page.locator('[data-hardware-action=manage][data-hardware-tag="ACTIVE-1"]').click();
    await page.locator('#lookupModal.active').waitFor();
    await page.locator('#assetPerson').selectOption('person-1');
    await page.getByRole('button',{name:'Save assignment',exact:true}).click();
    await page.waitForFunction(()=>data.workstations.find(w=>w.workstationTag==='ACTIVE-1').status==='ASSIGNED');
    assert.equal((await prisma.workstation.findUnique({where:{workstationTag:'ACTIVE-1'}})).personnelId,'person-1');
    await page.locator('[data-hardware-action=manage][data-hardware-tag="ACTIVE-1"]').click();
    await page.locator('#lookupModal.active').waitFor();
    await page.locator('#assetNextStatus').selectOption('OUT_OF_ORDER');
    await page.getByRole('button',{name:'Save status',exact:true}).click();
    await page.waitForFunction(()=>data.workstations.find(w=>w.workstationTag==='ACTIVE-1').status==='OUT_OF_ORDER');
    await page.locator('[data-hardware-action=manage][data-hardware-tag="ACTIVE-1"]').click();
    await page.locator('#lookupModal.active').waitFor();
    await page.locator('#assetNextStatus').selectOption('IN_STORE');
    await page.getByRole('button',{name:'Save status',exact:true}).click();
    await page.waitForFunction(()=>data.workstations.find(w=>w.workstationTag==='ACTIVE-1').status==='IN_STORE');
    assert.equal((await prisma.workstation.findUnique({where:{workstationTag:'ACTIVE-1'}})).personnelId,null);


    await page.evaluate(()=>openUserModal('editor@example.invalid'));
    await page.locator('#customAccess').check();await page.locator('[data-permission=edit]').uncheck();
    await page.locator('[data-permission=reports]').check();
    await page.screenshot({path:path.join(folder,'user-access-phone.png'),fullPage:true});
    await page.locator('#userForm button[type=submit]').click();await page.locator('#userModal.active').waitFor({state:'detached'});
    const access=await prisma.appSetting.findUnique({where:{key:'__access:editor@example.invalid'}});assert.equal(JSON.parse(access.value).edit,false);
   }else{
    await page.evaluate(()=>switchTab('reports'));await page.getByRole('button',{name:'Generate report',exact:true}).click();
    await page.locator('#reportPreview table').waitFor();assert.equal(await page.getByRole('button',{name:'Scrap Items Report',exact:true}).count(),0);
   }
   assert.deepEqual(errors,[]);await page.close();
  }
  console.log(JSON.stringify({passed:true,artifacts:folder}));
 }finally{await browser.close();await new Promise(r=>server.close(r));await prisma.$disconnect();}
})().catch(e=>{console.error(e);process.exitCode=1;});
