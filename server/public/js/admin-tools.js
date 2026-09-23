// A product of Mahzaidex Tech Developed by Hasnain Zaidi.
const AdminTools = (() => {
  let busy = false;
  const allowed = () => currentUser?.role === 'ADMIN';
  const types = [['inventory','Inventory items'],['personnel','Person-wise inventory'],['warranty','Warranty register'],['users','User accounts'],['audit','Audit records']];
  async function download(url,name,options={}) {
    const response=await fetch(url,{...options,headers:{Authorization:`Bearer ${token}`,...options.headers}});
    if(!response.ok) {const error=await response.json();throw new Error(error.error?.message||'Download failed.');}
    const blob=await response.blob(),link=document.createElement('a'),objectUrl=URL.createObjectURL(blob);
    link.href=objectUrl;link.download=name;link.click();setTimeout(()=>URL.revokeObjectURL(objectUrl),1000);
  }
  async function action(fn) {
    if(!allowed()||busy)return;
    busy=true;document.querySelectorAll('.admin-action').forEach(b=>b.disabled=true);
    try {await fn();} catch(e){showToast(e.message,'error');}
    finally {busy=false;document.querySelectorAll('.admin-action').forEach(b=>b.disabled=false);}
  }
  function reports(container) {
    if(!allowed())return;
    container.innerHTML=`<div class="page-header"><div class="page-title"><h1>Reports</h1><button class="btn btn-secondary" onclick="ScrapTools.open()">Scrap Items Report</button><p>Generate current inventory and administration records.</p></div></div>
    <section class="settings-pane"><div class="admin-form-grid">
    <label>Report<select id="reportType">${types.map(([v,l])=>`<option value="${v}">${l}</option>`).join('')}</select></label>
    <label>Asset status<select id="reportStatus"><option value="">All statuses</option>${['IN_STORE','ASSIGNED','RETIRED','OUT_OF_ORDER','SCRAPPED'].map(s=>`<option>${s}</option>`).join('')}</select></label>
    <label>Person<select id="reportPerson"><option value="">Everyone</option>${data.personnel.map(p=>`<option value="${escapeHtml(p.id)}">${escapeHtml(p.fullName)}</option>`).join('')}</select></label>
    <label>Audit records from<input type="date" id="reportFrom"></label><label>Audit records through<input type="date" id="reportTo"></label></div>
    <div class="admin-actions"><button class="btn btn-primary admin-action" onclick="AdminTools.generate(false)">Generate report</button><button class="btn btn-secondary admin-action" onclick="AdminTools.generate(true)">Download Excel</button></div>
    <p class="muted">Status and person filters apply to asset reports. Dates apply to audit records.</p><div id="reportPreview" aria-live="polite"></div></section>`;
  }
  function generate(exportFile) {return action(async()=>{
    const query=new URLSearchParams({type:document.getElementById('reportType').value,status:document.getElementById('reportStatus').value,personnelId:document.getElementById('reportPerson').value,from:document.getElementById('reportFrom').value,to:document.getElementById('reportTo').value});
    if(exportFile) {query.set('format','xlsx');return download('/api/admin/reports?'+query,'assetflow-report.xlsx');}
    const report=await api('/api/admin/reports?'+query);
    const target=document.getElementById('reportPreview');if(!target)return;
    target.innerHTML=`<p>${report.total} records · ${escapeHtml(new Date(report.generatedAt).toLocaleString())}${report.total>500?' · Preview shows first 500; Excel includes all records.':''}</p><div class="table-container"><table><thead><tr>${report.columns.map(c=>`<th>${escapeHtml(c)}</th>`).join('')}</tr></thead><tbody>${report.rows.map(row=>`<tr>${report.columns.map(c=>`<td>${escapeHtml(String(row[c]??''))}</td>`).join('')}</tr>`).join('')||`<tr><td colspan="${report.columns.length}">No matching records.</td></tr>`}</tbody></table></div>`;
  });}
  async function backups(pane) {
    if(!allowed())return;
    pane.innerHTML='<div class="settings-pane">Loading backups…</div>';
    try {
      const state=await api('/api/admin/backups');if(!pane.isConnected||currentSettingsSubTab!=='backups')return;
      pane.innerHTML=`<section class="settings-pane"><h3>Backup and Restore</h3><p>Daily server backups. The latest 10 Excel exports and 10 automatic restorable backups are retained separately. Manual and pre-restore recovery copies are kept.</p>
      <p>Full-state backups include inventory, personnel, accounts, password hashes, settings, custom fields and audit records. Store downloaded copies securely. Excel exports are for reference; use a full-state file to restore.</p>
      ${state.lastError?`<p role="alert">${escapeHtml(state.lastError)}</p>`:''}
      <div class="admin-actions"><button class="btn btn-primary admin-action" onclick="AdminTools.createBackup()">Back up complete state</button><button class="btn btn-secondary admin-action" onclick="document.getElementById('restoreBackupFile').click()">Restore from file</button><input id="restoreBackupFile" type="file" accept=".json" hidden onchange="AdminTools.uploadRestore(this)"></div>
      ${[['automatic','Automatic restorable backups'],['manual','Manual & recovery backups'],['excel','Excel backups — Backup folder']].map(([kind,label])=>`<h4>${label}</h4><div class="backup-list">${state[kind].map(f=>`<div class="backup-row"><div><strong>${escapeHtml(new Date(f.createdAt).toLocaleString())}</strong><small>${escapeHtml(f.name)} · ${Math.ceil(f.bytes/1024)} KB</small></div><button class="btn btn-secondary admin-action" data-kind="${kind}" data-name="${escapeHtml(f.name)}" onclick="AdminTools.downloadBackup(this)">Download</button>${kind!=='excel'?`<button class="btn btn-danger-outline admin-action" data-kind="${kind}" data-name="${escapeHtml(f.name)}" onclick="AdminTools.restoreSaved(this)">Restore</button>`:''}</div>`).join('')||'<p class="muted">No backups yet.</p>'}</div>`).join('')}</section>`;
    }catch(e){pane.textContent='Unable to load backups. '+e.message;}
  }
  const refresh=()=>backups(document.getElementById('settingsPaneContainer'));
  function createBackup(){return action(async()=>{const saved=await api('/api/admin/backups',{method:'POST'});await download(`/api/admin/backups/manual/${encodeURIComponent(saved.name)}`,saved.name);await refresh();});}
  function downloadBackup(button){return action(()=>download(`/api/admin/backups/${button.dataset.kind}/${encodeURIComponent(button.dataset.name)}`,button.dataset.name));}
  const confirmRestore=()=>prompt('Restore replaces all current application data, including user accounts and passwords. A recovery copy will be saved first. Type RESTORE to continue.')==='RESTORE';
  function restoreSaved(button){return action(async()=>{if(!confirmRestore())return;await api('/api/admin/restore',{method:'POST',body:{kind:button.dataset.kind,name:button.dataset.name,confirmation:'RESTORE'}});handleLogout();});}
  function uploadRestore(input){const file=input.files[0];input.value='';if(!file)return;return action(async()=>{if(!confirmRestore())return;const form=new FormData();form.append('file',file);form.append('confirmation','RESTORE');await api('/api/admin/restore',{method:'POST',body:form});handleLogout();});}
  function deletePane(pane) {
    if(!allowed())return;
    pane.innerHTML=`<section class="settings-pane"><h3>Super Power Delete</h3><p>Permanently delete one inventory item. No new audit entry or notification is created. Existing historical records remain. Attached peripherals are kept when a workstation is deleted.</p>
    <form onsubmit="event.preventDefault();AdminTools.remove()"><div class="admin-form-grid"><label>Item type<select id="deleteKind" onchange="AdminTools.fillAssets()"><option value="workstation">Workstation</option><option value="peripheral">Peripheral</option></select></label><label>Inventory item<select id="deleteTag" required></select></label><label>Type the exact tag to confirm<input id="deleteConfirmation" required autocomplete="off"></label></div><button class="btn btn-danger-outline admin-action" type="submit">Permanently delete item</button></form></section>`;
    fillAssets();
  }
  function fillAssets(){const kind=document.getElementById('deleteKind').value;document.getElementById('deleteTag').innerHTML='<option value="">Select an item</option>'+data[kind==='workstation'?'workstations':'peripherals'].map(a=>{const tag=a[kind+'Tag'];return `<option value="${escapeHtml(tag)}">${escapeHtml(tag)}</option>`;}).join('');}
  function remove(){return action(async()=>{const kind=document.getElementById('deleteKind').value,tag=document.getElementById('deleteTag').value,confirmation=document.getElementById('deleteConfirmation').value;if(!tag||tag!==confirmation)throw new Error('Type the exact selected tag to confirm.');await api('/api/admin/super-delete',{method:'POST',body:{kind,tag,confirmation}});await loadAllData();const pane=document.getElementById('settingsPaneContainer');if(pane&&currentSettingsSubTab==='super-delete')deletePane(pane);});}
  return {reports,generate,backups,createBackup,downloadBackup,restoreSaved,uploadRestore,deletePane,fillAssets,remove};
})();
