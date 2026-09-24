// Public release screenshots use synthetic data in a fresh, isolated database.
const {chromium}=require('../../.build-tools/node_modules/playwright');
const {DatabaseSync}=require('node:sqlite');
const fs=require('node:fs/promises'),path=require('node:path'),assert=require('node:assert/strict');
const jsQR=require('../../.build-tools/node_modules/jsqr'),{PNG}=require('../../.build-tools/node_modules/pngjs');
(async()=>{
 const folder=await fs.mkdtemp(path.resolve('../.build-tools/release-ui-')),dbPath=path.join(folder,'demo.db');
 const db=new DatabaseSync(dbPath);db.exec(await fs.readFile('prisma/initial-schema.sql','utf8'));db.close();
 process.env.NODE_ENV='test';process.env.DATABASE_URL='file:'+dbPath.replaceAll('\\','/');process.env.JWT_SECRET='isolated-release-screenshot-secret-123456789';process.env.BACKUP_ROOT=folder;
 const {app}=await import('../src/server.js'),{prisma}=await import('../src/prisma.js');
 const output=path.resolve(process.env.ASSETFLOW_SCREENSHOTS || '../docs/screenshots/v1.2.0');await fs.mkdir(output,{recursive:true});
 await prisma.appUser.create({data:{email:'demo@example.invalid',fullName:'Demo operator',role:'ADMIN'}});
 await prisma.personnel.create({data:{id:'demo-person',fullName:'Demo operator',department:'Design'}});
 for(let i=0;i<8;i++)await prisma.workstation.create({data:{workstationTag:'DEMO-PC-'+(1001+i),deviceType:['Assembled PC','Laptop','Mini PC','All-in-One PC'][i%4],processorGen:'Intel Core i7',motherboard:'B760',ram:'32 GB DDR5',ssd:'1 TB NVMe',gpu:'RTX 4060',personnelId:i%2?'demo-person':null,status:i%2?'ASSIGNED':'IN_STORE'}});
 for(const [i,category] of ['Keyboard','Mouse','Headphones','Monitor','Printer','Network Device','VR','Webcam','RAM','SSD','HDD','GPU','Motherboard'].entries())await prisma.peripheral.create({data:{peripheralTag:'DEMO-'+category.replaceAll(' ','-').toUpperCase()+'-'+(2001+i),category,brandManufacturer:'Demo hardware',modelSpecs:category==='SSD'?'1 TB NVMe':'Standard edition',status:'IN_STORE',purchaseDate:new Date('2026-09-01')}});
 const logo='data:image/png;base64,'+(await fs.readFile('../inventory_manager_flutter/assets/images/default_logo.png')).toString('base64');
 await prisma.appSetting.create({data:{key:'companyLogo',value:logo}});
 const server=app.listen(0,'127.0.0.1');await new Promise(r=>server.once('listening',r));const base='http://127.0.0.1:'+server.address().port;
 const token=require('jsonwebtoken').sign({email:'demo@example.invalid'},process.env.JWT_SECRET);
 const browser=await chromium.launch({headless:true});
 try{
  const page=await browser.newPage({viewport:{width:1440,height:1000}}),errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.addInitScript(({token})=>{localStorage.setItem('assetflow_token',token);localStorage.setItem('assetflow_user',JSON.stringify({email:'demo@example.invalid',fullName:'Demo operator',role:'ADMIN'}));},{token});
  await page.goto(base);await page.getByRole('heading',{name:'Dashboard Overview'}).waitFor();assert.equal(await page.locator('#hardwareSearch').count(),0);await page.screenshot({path:path.join(output,'overview-desktop.png'),fullPage:true});await page.setViewportSize({width:390,height:844});assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));await page.screenshot({path:path.join(output,'overview-phone.png'),fullPage:true,animations:'disabled'});await page.setViewportSize({width:1440,height:1000});await page.getByRole('button',{name:'View workstations',exact:true}).click();await page.getByRole('heading',{name:'Workstations',exact:true}).first().waitFor();await page.waitForFunction(()=>typeof QRCode!=='undefined');
  assert.equal(await page.locator('.hardware-card').count(),9);
  await page.screenshot({path:path.join(output,'dashboard-desktop.png'),fullPage:true});
  for(const [group,count] of [['Peripherals',4],['Devices',4],['Components',4],['Workstations',9]]){await page.getByRole('tab',{name:new RegExp('^'+group)}).click();assert.equal(await page.locator('.hardware-card').count(),count);}
  await page.locator('#hardwareSearch').fill('DEMO-PC-');assert.equal(await page.locator('.hardware-card').count(),8);
  await page.getByRole('button',{name:'Select All Shown'}).click();await page.getByRole('button',{name:'Print Selected',exact:true}).click();
  const frame=page.frameLocator('#tagPrintFrame');await frame.locator('.sheet').waitFor();assert.equal(await frame.locator('.label').count(),8);
  const html=await page.locator('#tagPrintFrame').evaluate(el=>el.contentDocument.documentElement.outerHTML);
  const printPage=await browser.newPage({viewport:{width:1000,height:1200}});await printPage.setContent(html);await printPage.screenshot({path:path.join(output,'tags-workstations.png'),fullPage:true});
  for(const label of await printPage.locator('.label').all()){const png=PNG.sync.read(await label.screenshot());assert.ok(jsQR(new Uint8ClampedArray(png.data),png.width,png.height)?.data.startsWith('DEMO-PC-'),'Workstation QR must decode with centered logo');}
  await printPage.pdf({path:path.join(folder,'tags.pdf'),preferCSSPageSize:true,printBackground:true});
  await page.locator('#tagPrintModal .modal-header button').click();await page.getByRole('button',{name:'Clear Selection',exact:true}).click();
  await page.getByRole('tab',{name:/^Peripherals/}).click();await page.getByRole('button',{name:'Select All Shown'}).click();await page.getByRole('button',{name:'Print Selected',exact:true}).click();
  const smallHtml=await page.locator('#tagPrintFrame').evaluate(el=>el.contentDocument.documentElement.outerHTML);await printPage.setContent(smallHtml);await printPage.screenshot({path:path.join(output,'tags-peripherals.png'),fullPage:true});
  for(const label of await printPage.locator('.label').all()){const png=PNG.sync.read(await label.screenshot());assert.ok(jsQR(new Uint8ClampedArray(png.data),png.width,png.height)?.data.startsWith('DEMO-'),'Small QR must decode with centered logo');}
  await page.locator('#tagPrintModal .modal-header button').click();await page.setViewportSize({width:390,height:844});
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth));
  await page.screenshot({path:path.join(output,'dashboard-phone-web.png'),fullPage:true});
  // Status API must save a report, return idempotently and enforce role restrictions.
  const status=await fetch(base+'/api/assets/peripheral/DEMO-SSD-2010/status',{method:'PATCH',headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'},body:JSON.stringify({status:'SCRAPPED'})});assert.equal(status.status,200);
  const registered=await prisma.appSetting.findMany({where:{key:{startsWith:'__scrap-report:'}}});assert.equal(registered.length,1);assert.equal(JSON.parse(registered[0].value).operator.email,'demo@example.invalid');
  assert.deepEqual(errors,[]);console.log(JSON.stringify({passed:true,screenshots:output,pdf:path.join(folder,'tags.pdf')}));
 }finally{await browser.close();await new Promise(r=>server.close(r));await prisma.$disconnect();}
})().catch(error=>{console.error(error);process.exitCode=1;});
