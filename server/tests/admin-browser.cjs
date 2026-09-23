// UI checks use an isolated database and backup directory.
const {chromium}=require('../../.build-tools/node_modules/playwright');
const {DatabaseSync,backup}=require('node:sqlite');
const fs=require('node:fs/promises'),path=require('node:path'),assert=require('node:assert/strict');
(async()=>{
 const root=await fs.mkdtemp(path.resolve('../.build-tools/admin-ui-'));
 const dbPath=path.join(root,'test.db');const source=new DatabaseSync(path.resolve('prisma/dev.db'),{readOnly:true});await backup(source,dbPath);source.close();
 process.env.NODE_ENV='test';process.env.DATABASE_URL='file:'+dbPath.replaceAll('\\','/');process.env.BACKUP_ROOT=root;
 const {app}=await import('../src/server.js');const {prisma}=await import('../src/prisma.js');
 await prisma.appUser.upsert({where:{email:'qa-admin@test'},create:{email:'qa-admin@test',fullName:'QA',role:'ADMIN',passwordHash:'test'},update:{role:'ADMIN'}});
 await prisma.appUser.upsert({where:{email:'qa-viewer@test'},create:{email:'qa-viewer@test',fullName:'Viewer',role:'VIEWER'},update:{role:'VIEWER'}});
 await prisma.workstation.create({data:{workstationTag:'DELETE-QA'}});
 const {createBackupService}=await import('../src/services/backup-service.js');await createBackupService(prisma,root).automatic();
 const server=app.listen(0,'127.0.0.1');await new Promise(r=>server.once('listening',r));
 const base=`http://127.0.0.1:${server.address().port}`,jwt=require('jsonwebtoken');
 const browser=await chromium.launch({headless:true});
 try {
  const page=await browser.newPage({viewport:{width:1440,height:1000}});const errors=[];page.on('pageerror',e=>errors.push(e.message));
  const token=jwt.sign({email:'qa-admin@test',role:'ADMIN'},process.env.JWT_SECRET||'assetflow-super-secret-production-key-2026');
  await page.addInitScript(token=>{localStorage.setItem('assetflow_token',token);localStorage.setItem('assetflow_user',JSON.stringify({email:'qa-admin@test',role:'ADMIN',fullName:'QA'}));},token);
  await page.goto(base);await page.locator('#viewContainer h1').waitFor();
  await page.locator('[data-tab="reports"]').click();await page.getByRole('button',{name:'Generate report',exact:true}).click();await page.locator('#reportPreview table').waitFor();
  const reportDownload=page.waitForEvent('download');await page.getByRole('button',{name:'Download Excel',exact:true}).click();assert.match((await reportDownload).suggestedFilename(),/xlsx$/);
  await page.screenshot({path:path.join(root,'reports-desktop.png'),fullPage:true});
  await prisma.workstation.create({data:{workstationTag:'SCRAP-QA',deviceType:'Test laptop'}});
  await page.getByRole('button',{name:'Scrap Items Report',exact:true}).click();await page.locator('#scrapTags').fill('SCRAP-QA');await page.getByRole('button',{name:'Retrieve item details'}).click();await page.getByText('Preview — nothing changed yet').waitFor();
  page.once('dialog',d=>d.accept());await page.getByRole('button',{name:'Confirm scrap & generate sheet'}).click();await page.getByRole('button',{name:'Print / Save PDF'}).waitFor();
  assert.equal((await prisma.workstation.findUnique({where:{workstationTag:'SCRAP-QA'}})).status,'SCRAPPED');
  const scrapDownload=page.waitForEvent('download');await page.getByRole('button',{name:'Export Excel',exact:true}).click();assert.match((await scrapDownload).suggestedFilename(),/xlsx$/);
  await page.screenshot({path:path.join(root,'scrap-report.png'),fullPage:true});

  await page.locator('[data-tab="settings"]').click();await page.locator('.subnav-btn').filter({hasText:'Backup and Restore'}).click();await page.getByRole('button',{name:'Back up complete state',exact:true}).waitFor();
  const manualDownload=page.waitForEvent('download');await page.getByRole('button',{name:'Back up complete state',exact:true}).click();assert.match((await manualDownload).suggestedFilename(),/json$/);await page.locator('.backup-row').nth(2).waitFor();
  await page.screenshot({path:path.join(root,'backups-desktop.png'),fullPage:true});
  await page.locator('.subnav-btn').filter({hasText:'Super Power Delete'}).click();await page.locator('#deleteTag').selectOption('DELETE-QA');await page.locator('#deleteConfirmation').fill('DELETE-QA');
  const logs=await prisma.auditLog.count();await page.getByRole('button',{name:'Permanently delete item'}).click();await page.waitForFunction(()=>!Array.from(document.querySelectorAll('#deleteTag option')).some(o=>o.value==='DELETE-QA'));assert.equal(await prisma.auditLog.count(),logs);
  await page.setViewportSize({width:390,height:844});await page.locator('.mobile-settings-select').selectOption('backups');await page.getByRole('button',{name:'Back up complete state',exact:true}).waitFor();await page.screenshot({path:path.join(root,'backups-mobile.png'),fullPage:true});
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));
  page.once('dialog',d=>d.accept('RESTORE'));await page.getByRole('button',{name:'Restore',exact:true}).first().click();await page.locator('#loginScreen').waitFor({state:'visible'});assert.ok(await prisma.workstation.findUnique({where:{workstationTag:'DELETE-QA'}}));
  const viewer=await browser.newPage();await viewer.addInitScript(token=>{localStorage.setItem('assetflow_token',token);localStorage.setItem('assetflow_user',JSON.stringify({email:'qa-viewer@test',role:'VIEWER',fullName:'Viewer'}));},jwt.sign({email:'qa-viewer@test',role:'VIEWER'},process.env.JWT_SECRET||'assetflow-super-secret-production-key-2026'));
  await viewer.goto(base);await viewer.locator('#viewContainer h1').waitFor();assert.equal(await viewer.locator('[data-tab="reports"]').isVisible(),false);assert.equal(await viewer.locator('[data-tab="settings"]').isVisible(),true);
  await viewer.locator('[data-tab="settings"]').click();await viewer.getByRole('heading',{name:'AI API Keys'}).waitFor();assert.equal(await viewer.getByText('Super Power Delete',{exact:true}).count(),0);
  const form=viewer.locator('.ai-key-form[data-provider="openai"]');await form.locator('[name="apiKey"]').fill('test-browser-key-only');await form.getByRole('button',{name:'Save key'}).click();await form.getByText('Saved: ••••••••').waitFor();assert.equal(await form.locator('[name="apiKey"]').inputValue(),'');
  const settings=await viewer.evaluate(async()=>await (await fetch('/api/settings',{headers:{Authorization:'Bearer '+localStorage.getItem('assetflow_token')}})).text());assert.ok(!settings.includes('test-browser-key-only'));assert.ok(!settings.includes('__ai:'));
  await form.getByRole('button',{name:'Remove key'}).click();await form.getByText('No key saved').waitFor();
  await viewer.setViewportSize({width:390,height:844});await viewer.screenshot({path:path.join(root,'ai-settings-phone.png'),fullPage:true});
  const denied=await viewer.evaluate(async()=> (await fetch('/api/admin/backups',{headers:{Authorization:'Bearer '+localStorage.getItem('assetflow_token')}})).status);assert.equal(denied,403);
  assert.deepEqual(errors,[]);console.log(JSON.stringify({passed:true,artifacts:root}));
 }finally{await browser.close();await new Promise(r=>server.close(r));await prisma.$disconnect();}
})().catch(e=>{console.error(e);process.exitCode=1;});
