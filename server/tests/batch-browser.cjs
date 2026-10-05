const {chromium}=require('../../.build-tools/node_modules/playwright');
const {DatabaseSync}=require('node:sqlite');
const fs=require('node:fs/promises'),path=require('node:path'),assert=require('node:assert/strict');
(async()=>{
 const folder=await fs.mkdtemp(path.resolve('../.build-tools/batch-ui-')),file=path.join(folder,'test.db');
 const db=new DatabaseSync(file);db.exec(await fs.readFile('prisma/initial-schema.sql','utf8'));db.close();
 process.env.NODE_ENV='test';process.env.DATABASE_URL='file:'+file.replaceAll('\\','/');process.env.JWT_SECRET='batch-ui-test-secret';process.env.BACKUP_ROOT=folder;
 const {app}=await import('../src/server.js'),{prisma}=await import('../src/prisma.js'),{default:jwt}=await import('jsonwebtoken');
 await prisma.appUser.create({data:{email:'admin',fullName:'Test',role:'ADMIN'}});
 const server=app.listen(0,'127.0.0.1');await new Promise(r=>server.once('listening',r));const browser=await chromium.launch();
 try{
  const page=await browser.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.addInitScript(token=>{localStorage.setItem('assetflow_token',token);localStorage.setItem('assetflow_user',JSON.stringify({email:'admin',role:'ADMIN'}));},jwt.sign({email:'admin'},process.env.JWT_SECRET));
  await page.route('**/*',r=>new URL(r.request().url()).hostname==='127.0.0.1'?r.continue():r.abort());
  await page.goto('http://127.0.0.1:'+server.address().port,{waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>typeof currentUser!=='undefined'&&currentUser.permissions);
  await page.evaluate(()=>{switchTab('peripherals');openPeripheralModal();});
  await page.locator('#perAddMode').selectOption('batch');await page.locator('#perQuantity').fill('10');
  assert.equal(await page.locator('[data-batch-tag]').count(),0);
  assert.match(await page.locator('#perBatchTags').textContent(),/10 individual items/);
  await page.locator('#perCategory').selectOption('Mouse');await page.locator('#perBrand').fill('Logitech');await page.locator('#perModelSpecs').fill('M100');await page.locator('#perReceiveDate').fill('2026-10-05');
  await page.locator('#btnSavePeripheral').click();await page.waitForFunction(()=>data.peripherals.length===10);
  assert.equal(await prisma.peripheral.count(),10);assert.equal(await prisma.peripheral.count({where:{quantity:1}}),10);
  await page.evaluate(()=>renderPeripherals(document.getElementById('viewContainer')));
  assert.equal(await page.locator('tbody tr').count(),10);
  await page.evaluate(()=>openPeripheralModal('PER-2004'));assert.equal(await page.locator('#perAddModeGroup').isVisible(),false);assert.equal(await page.locator('#perReceiveDate').inputValue(),'2026-10-05');
  assert.deepEqual(errors,[]);console.log('PASS: quantity 10 generates unique tags and saves 10 independent rows, and retains single-item editing');
 }finally{await browser.close();await new Promise(r=>server.close(r));await prisma.$disconnect();}
})().catch(e=>{console.error(e);process.exit(1)});
