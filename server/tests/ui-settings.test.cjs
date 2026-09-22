const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');

function context() {
  const sandbox = vm.createContext({ localStorage: { getItem: () => null }, document: { getElementById: () => null, addEventListener() {} } });
  vm.runInContext(fs.readFileSync(path.join(__dirname, '../public/js/app.js'), 'utf8'), sandbox);
  return sandbox;
}
test('generated tags honor start/digit settings and never reuse existing sequence numbers', () => {
  const c = context();
  vm.runInContext(`data.settings = {tagPrefixWs:'IT', tagSeparator:'/', tagSeqStart:'20', tagSeqLength:'5'};
    data.workstations = [{workstationTag:'IT/00020'}, {workstationTag:'IT/00024'}, {workstationTag:'OLD-99999'}];`, c);
  assert.equal(vm.runInContext("nextAssetTag('workstation')", c), 'IT/00025');
  assert.equal(vm.runInContext('data.workstations.length', c), 3);
});
test('tag settings preserve false choices and bound QR dimensions', () => {
  const c = context();
  vm.runInContext(`data.settings.tagConfig = JSON.stringify({showCompany:false, showUser:false, qrSize:999});`, c);
  assert.equal(vm.runInContext('getTagConfig().showCompany', c), false);
  assert.equal(vm.runInContext('getTagConfig().showUser', c), false);
  assert.equal(vm.runInContext('getTagConfig().qrSize', c), 120);
});
test('invalid old configuration falls back safely', () => {
  const c = context();
  vm.runInContext("data.settings.tagConfig = 'invalid'", c);
  assert.equal(vm.runInContext('getTagConfig().showCompany', c), true);
});
