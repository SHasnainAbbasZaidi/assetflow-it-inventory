const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm'),fs=require('node:fs'),path=require('node:path');
const context=vm.createContext({});vm.runInContext(fs.readFileSync(path.join(__dirname,'../public/js/tag-layout.js'),'utf8'),context);
const {defaults,paginate,search}=context.TagLayout;
test('A6 and A7 print with four/eight tags, safe margins and intact proportions',()=>{
 for(const [kind,count] of [['workstation',4],['peripheral',8]]){
  const template=defaults(kind);const pages=paginate(Array.from({length:count+1},()=>({template})));
  assert.equal(pages.length,2);assert.equal(pages[0].items.length,count);
  for(const p of pages){assert.ok(p.width*p.cols+4*(p.cols-1)<=(p.landscape?277:190)+0.001);assert.ok(p.height*p.rows+4*(p.rows-1)<=(p.landscape?190:277)+0.001);assert.ok(Math.abs(p.width/p.height-template.width/template.height)<1e-9);}
 }
});
test('mixed sizes get separate pages',()=>{const pages=paginate([{template:defaults('workstation')},{template:defaults('peripheral')}]);assert.equal(pages.length,2);});
test('case-insensitive partial search matches all supported fields and handles empty input',()=>{
 const rows=[{tag:'WS-1001',fields:{tag:'WS-1001',name:'Design PC',type:'Workstation',company:'MAH Systems'}}];
 for(const q of [' 100 ','design','WORKSTATION','mah'])assert.equal(search(rows,q).length,1);
 assert.equal(search(rows,' ').length,0);assert.equal(search(rows,'none').length,0);
});
