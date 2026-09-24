(function(root){
  const groups=['Workstations','Peripherals','Devices','Components'];
  function classify(category,kind='peripheral') {
    if(kind==='workstation') return 'Workstations';
    const c=String(category||'').toLowerCase().replace(/[-_/]/g,' ');
    if(/\b(motherboard|mainboard|laptop|desktop|computer|workstation|pc|aio)\b|all in one/.test(c)) return 'Workstations';
    if(/\b(ram|ssd|hdd|gpu|cpu|processor|memory|storage|graphics|psu|power supply|cooler|internal|component)\b/.test(c)) return 'Components';
    if(/\b(printer|scanner|network|networking|router|switch|firewall|access point|modem|vr|webcam|camera|projector|server|nas|tablet|mobile)\b/.test(c)) return 'Devices';
    return 'Peripherals';
  }
  const api={groups,classify};if(typeof module!=='undefined')module.exports=api;else root.HardwareGroups=api;
})(typeof window==='undefined'?globalThis:window);
