// End-to-end checks run against an isolated SQLite snapshot, never the live app database.
const { chromium }=require('../../.build-tools/node_modules/playwright');
const { DatabaseSync,backup }=require('node:sqlite');
const fs=require('node:fs/promises'),path=require('node:path'),assert=require('node:assert/strict');
(async()=>{
 const folder=await fs.mkdtemp(path.resolve('../.build-tools/browser-'));
 const dbPath=path.join(folder,'browser.db');
 const source=new DatabaseSync(path.resolve('prisma/dev.db'),{readOnly:true});await backup(source,dbPath);source.close();
 process.env.NODE_ENV='test';process.env.DATABASE_URL='file:'+dbPath.replaceAll('\\','/');
 const {app}=await import('../src/server.js');const {prisma}=await import('../src/prisma.js');
 const jwt=require('jsonwebtoken');
 const server=app.listen(0,'127.0.0.1');await new Promise(r=>server.once('listening',r));
 const base=`http://127.0.0.1:${server.address().port}`;
 for(let i=0;i<5;i++)await prisma.workstation.create({data:{workstationTag:'QA-WS-'+i,deviceType:'Design Workstation',processorGen:'Test CPU',status:'IN_STORE'}});
 for(let i=0;i<9;i++)await prisma.peripheral.create({data:{peripheralTag:'QA-PER-'+i,category:'Monitor',modelSpecs:'Design Display',status:'IN_STORE'}});
 console.log('Fixture ready');
 await prisma.appUser.upsert({where:{email:'qa'},create:{email:'qa',fullName:'QA',role:'ADMIN'},update:{role:'ADMIN'}});
 const token=jwt.sign({email:'qa',role:'ADMIN'},process.env.JWT_SECRET || 'assetflow-super-secret-production-key-2026');
 const browser=await chromium.launch({headless:true});
 try{
 console.log('Browser started');
 const page=await browser.newPage({viewport:{width:1440,height:1000}});const errors=[];page.on('pageerror',e=>errors.push(e.message));page.setDefaultTimeout(20000);
 await page.addInitScript(({token})=>{localStorage.setItem('assetflow_token',token);localStorage.setItem('assetflow_user',JSON.stringify({email:'qa',role:'ADMIN',fullName:'QA'}));},{token});
 await page.goto(base,{waitUntil:'domcontentloaded'});console.log('Page loaded');await page.locator('#viewContainer h1').waitFor();await page.waitForFunction(()=>typeof QRCode!=='undefined');console.log('App ready');
 await page.locator('#globalSearchInput').fill(' qa-ws- ');await page.waitForSelector('#globalSearchResults button');assert.equal(await page.locator('#globalSearchResults button').count(),5);
 await page.locator('#globalSearchInput').fill('  ');await page.waitForFunction(()=>!document.querySelector('#globalSearchResults'));
 await page.locator('[data-tab="settings"]').click();await page.locator('.subnav-btn').filter({hasText:'Tag Customizer'}).click();
 await page.locator('#studioStage svg').waitFor();assert.ok(await page.getByText('A product of Mahzaidex Tech',{exact:false}).count());
 await page.getByRole('button',{name:'Add text',exact:true}).click();await page.locator('[data-prop="text"]').fill('QA editor text');await page.locator('[data-prop="text"]').dispatchEvent('change');
 await page.locator('#templateName').fill('QA custom template');await page.locator('#templateName').dispatchEvent('change');
 await page.getByRole('button',{name:'Save Template',exact:true}).click();await page.getByText('Template saved and selected for printing',{exact:true}).waitFor();
 await page.reload();await page.locator('#viewContainer h1').waitFor();await page.locator('[data-tab="settings"]').click();await page.locator('.subnav-btn').filter({hasText:'Tag Customizer'}).click();assert.equal(await page.locator('#templateName').inputValue(),'QA custom template');
 await page.getByRole('button',{name:'Duplicate',exact:true}).click();assert.match(await page.locator('#templateName').inputValue(),/copy/);
 // Restore default templates in this isolated fixture so print checks cover standard A6/A7 layouts.
 await page.evaluate(async()=>{await api('/api/settings',{method:'POST',body:{tagTemplates:'',workstationTemplate:'',peripheralTemplate:''}});data.settings.tagTemplates='';data.settings.workstationTemplate='';data.settings.peripheralTemplate='';});
 await page.locator('[data-tab="workstations"]').click();await page.locator('#hardwareSearch').fill('QA-WS');await page.getByRole('button',{name:'Select All Shown'}).click();
 assert.equal(await page.locator('.tag-select:checked').count(),5);
 await page.locator('[data-tab="peripherals"]').click();await page.locator('#hardwareSearch').fill('QA-PER');await page.getByRole('button',{name:'Select All Shown'}).click();await page.getByRole('button',{name:'Print Selected',exact:true}).click();
 const frame=page.frameLocator('#tagPrintFrame');await frame.locator('.sheet').first().waitFor();assert.equal(await frame.locator('.sheet').count(),2);assert.equal(await frame.locator('.label').count(),14);
 const geometry=await page.locator('#tagPrintFrame').evaluate(el=>Array.from(el.contentDocument.querySelectorAll('.sheet')).map(sheet=>{const s=sheet.getBoundingClientRect();return Array.from(sheet.querySelectorAll('.label')).every(label=>{const r=label.getBoundingClientRect();return r.left>=s.left&&r.right<=s.right+1&&r.top>=s.top&&r.bottom<=s.bottom+1;});}));assert.ok(geometry.every(Boolean));
 const html=await page.locator('#tagPrintFrame').evaluate(el=>el.contentDocument.documentElement.outerHTML);
 const printPage=await browser.newPage();await printPage.setContent(html);await printPage.emulateMedia({media:'print'});
 const pdf=await printPage.pdf({path:path.join(folder,'bulk-tags.pdf'),preferCSSPageSize:true,printBackground:true});
 const pages=(pdf.toString('latin1').match(/\/Type\s*\/Page\b/g)||[]).length;assert.equal(pages,2);
 await printPage.screenshot({path:path.join(folder,'print-preview.png'),fullPage:true});
 await page.locator('#tagPrintModal .modal-header button').click();await page.locator('[data-tab="settings"]').click();await page.locator('.subnav-btn').filter({hasText:'Tag Customizer'}).click();await page.screenshot({path:path.join(folder,'editor-desktop.png'),fullPage:true});
 await page.setViewportSize({width:390,height:844});await page.screenshot({path:path.join(folder,'editor-mobile.png'),fullPage:true});
 assert.deepEqual(errors,[]);console.log(JSON.stringify({passed:true,pdfPages:pages,artifacts:folder}));
 }finally{await browser.close();await new Promise(r=>server.close(r));await prisma.$disconnect();}
})().catch(e=>{console.error(e);process.exitCode=1;});
