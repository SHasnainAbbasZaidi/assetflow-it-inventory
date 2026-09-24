const {test}=require('node:test'),assert=require('node:assert/strict');
const vm=require('node:vm'),fs=require('node:fs'),path=require('node:path');
const context=vm.createContext({});vm.runInContext(fs.readFileSync(path.join(__dirname,'../public/js/hardware-groups.js'),'utf8'),context);const {classify}=context.HardwareGroups;
test('all hardware categories have a stable group without database changes',()=>{
 for(const [group,categories] of Object.entries({Workstations:['Assembled PC','Motherboard','Laptop','Mini PC','All-in-One PC'],Peripherals:['Keyboard','Mouse','Headphones','Display','Unknown legacy accessory'],Devices:['Printer','Network Device','VR','Webcam'],Components:['RAM','SSD','HDD','GPU']}))for(const c of categories)assert.equal(classify(c),group,c);
 assert.equal(classify('Dell','workstation'),'Workstations');
});
