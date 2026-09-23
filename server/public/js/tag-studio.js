/* Shared SVG renderer: editor, preview and printed sheets use the same geometry. */
const TagStudio = (() => {
    const selected = new Map();
    let templates, active, draft, selectedElement, editorAsset, dragging;
    const qrCache = new Map();
    const clone = value => JSON.parse(JSON.stringify(value));
    const esc = value => escapeHtml(String(value ?? ''));
    const number = (value, fallback=0) => Number.isFinite(Number(value)) ? Number(value) : fallback;
    const color = (value, fallback='#111827') => /^#[0-9a-f]{6}$/i.test(value || '') ? value : fallback;
    const fields = ['companyName','companyAddress','tag','device','person','specs','status','purchaseDate'];
    function load() {
        try { templates = JSON.parse(data.settings.tagTemplates || 'null'); } catch (_) { templates = null; }
        if (!Array.isArray(templates) || !templates.length) templates = ['workstation','peripheral'].map(TagLayout.defaults);
        templates = templates.filter(t => t && Array.isArray(t.elements) && t.width > 0 && t.height > 0);
        if (!templates.length) templates = ['workstation','peripheral'].map(TagLayout.defaults);
    }
    function asset(kind, tag) {
        const ws = kind === 'workstation';
        const item = (ws ? data.workstations : data.peripherals).find(a => a[ws ? 'workstationTag' : 'peripheralTag'] === tag);
        if (!item) return null;
        return { kind, tag, fields:{ tag, companyName:data.settings.companyName || 'AssetFlow', companyAddress:data.settings.companyAddress || '',
            device: ws ? item.deviceType || 'Workstation' : [item.category,item.brandManufacturer,item.modelSpecs].filter(Boolean).join(' · '),
            person:item.personnel?.fullName || item.userName || item.workstation?.personnel?.fullName || 'Unassigned',
            specs:ws ? ['CPU: '+(item.processorGen || '—'),'Motherboard: '+(item.motherboard || '—'),'RAM: '+(item.ram || '—'),'Storage: '+([item.ssd,item.hdd].filter(Boolean).join(' / ') || '—'),'GPU: '+(item.gpu || '—')].join('\n') : item.modelSpecs || '',
            status:item.status, purchaseDate:formatDate(item.purchaseDate) } };
    }
    function qr(value) {
        if(qrCache.has(value)) return qrCache.get(value);
        if (!window.QRCode) throw Error('QR library could not load. Check your connection and reload before printing.');
        const holder = document.createElement('div');
        new QRCode(holder, { text:value, width:256, height:256, correctLevel:QRCode.CorrectLevel.M });
        const canvas = holder.querySelector('canvas');
        if (!canvas) throw Error('Unable to generate QR code');
        const encoded=canvas.toDataURL('image/png');
        if(qrCache.size>256) qrCache.clear();
        qrCache.set(value,encoded);return encoded;
    }
    function svg(template, record, editing=false) {
        const root = document.createElementNS('http://www.w3.org/2000/svg','svg');
        root.setAttribute('viewBox', `0 0 ${template.width} ${template.height}`);
        root.setAttribute('width','100%'); root.setAttribute('height','100%');
        root.setAttribute('role','img'); root.setAttribute('aria-label',`Tag ${record?.tag || template.name}`);
        root.innerHTML = `<rect width="100%" height="100%" fill="${color(template.background,'#ffffff')}"/>`;
        const qrImage = record ? qr(record.tag) : null;
        for (const e of template.elements) {
            const x=number(e.x), y=number(e.y), w=Math.max(1,number(e.w,20)), h=Math.max(1,number(e.h,10));
            const g = document.createElementNS(root.namespaceURI,'g');
            g.dataset.element=e.id;
            g.innerHTML = `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${e.background ? color(e.background,'#ffffff') : 'none'}" stroke="${color(e.borderColor,'#000000')}" stroke-width="${Math.max(0,number(e.borderWidth))}"/>`;
            if (['logo','image','qr'].includes(e.type)) {
                const src = e.type === 'logo' ? getCompanyLogo() : e.type === 'qr' ? qrImage : e.src;
                if (src && /^data:image\/(png|jpeg|gif);base64,/i.test(src)) {
                    const image = document.createElementNS(root.namespaceURI,'image');
                    image.setAttribute('href',src); image.setAttribute('x',x); image.setAttribute('y',y); image.setAttribute('width',w); image.setAttribute('height',h); image.setAttribute('preserveAspectRatio','xMidYMid meet');
                    g.append(image);
                } else if (editing) g.innerHTML += `<text x="${x+1}" y="${y+4}" font-size="3" fill="#64748b">${esc(e.type === 'qr' ? 'QR · select a real asset' : e.type)}</text>`;
            } else {
                const text = e.type === 'field' ? record?.fields[e.field] ?? `{${e.field}}` : e.text || 'Text';
                let size=Math.max(1,Math.min(20,number(e.fontSize,3.5))), lines=[];
                const pad=Math.max(0,Math.min(w/4,number(e.padding,0.5)));
                for (let attempt=0;attempt<30;attempt++) {
                    lines=[];
                    const chars=Math.max(1,Math.floor((w-pad*2)/(size*0.58)));
                    for (const paragraph of String(text).split('\n')) {
                        let rest=paragraph;
                        while(rest.length>chars) { let cut=rest.lastIndexOf(' ',chars); if(cut<1) cut=chars; lines.push(rest.slice(0,cut)); rest=rest.slice(cut).trimStart(); }
                        lines.push(rest);
                    }
                    if (lines.length*size*1.25<=h-pad*2) break;
                    size*=0.9;
                }
                const anchor=e.align==='center'?'middle':e.align==='right'?'end':'start';
                const tx=e.align==='center'?x+w/2:e.align==='right'?x+w-pad:x+pad;
                g.innerHTML += `<text x="${tx}" y="${y+pad+size}" font-family="${['Arial','Georgia','Courier New'].includes(e.font)?e.font:'Arial'}" font-size="${size}" font-weight="${e.bold?'bold':'normal'}" fill="${color(e.color)}" text-anchor="${anchor}">${lines.map((line,i)=>`<tspan x="${tx}" dy="${i?size*1.25:0}">${esc(line)}</tspan>`).join('')}</text>`;
            }
            if(editing) {
                g.innerHTML += `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="transparent" stroke="${selectedElement===e.id?'#6366f1':'#cbd5e1'}" stroke-width="0.4" stroke-dasharray="1 1"/>`;
                if(selectedElement===e.id) g.innerHTML += `<rect data-resize="true" x="${x+w-3}" y="${y+h-3}" width="3" height="3" fill="#6366f1"/>`;
            }
            root.append(g);
        }
        return root;
    }
    function templateFor(kind) {
        const id=data.settings[kind==='workstation'?'workstationTemplate':'peripheralTemplate'];
        const saved=templates.find(t=>t.id===id) || templates.find(t=>t.kind===kind);
        const t=clone(saved || TagLayout.defaults(kind));
        // Preserve the previous simple customizer configuration for default templates.
        if(t.id.startsWith('default-')) {
            const c=getTagConfig();
            t.elements=t.elements.filter(e=> (c.showCompany || !['logo','company','address'].includes(e.id)) && (c.showUser || e.id!=='person') && (c.showDeviceName || !['device','specs'].includes(e.id)));
        }
        return t;
    }
    function preview(records, override) {
        load();
        const items=records.filter(Boolean).map(r=>({ record:r,template:override || templateFor(r.kind) }));
        if(!items.length) return showToast('Select at least one tag','error');
        const frame=document.getElementById('tagPrintFrame');
        const doc=frame.contentDocument;
        doc.open(); doc.write('<!doctype html><html><head><title>Asset tags</title></head><body></body></html>'); doc.close();
        const style=doc.createElement('style');
        style.textContent=`*{box-sizing:border-box}body{margin:0;background:#e2e8f0}.sheet{width:210mm;height:297mm;padding:10mm;background:white;display:grid;gap:4mm;align-content:start;justify-content:start;margin:8px auto;break-after:page;page:portrait}.sheet.landscape{width:297mm;height:210mm;page:landscape}.label{break-inside:avoid;page-break-inside:avoid}.label svg{display:block} @page portrait{size:A4 portrait;margin:0}@page landscape{size:A4 landscape;margin:0}@media print{body{background:white}.sheet{margin:0;box-shadow:none}.sheet:last-child{break-after:auto}*{print-color-adjust:exact;-webkit-print-color-adjust:exact}}`;
        doc.head.append(style);
        try {
            for(const page of TagLayout.paginate(items)) {
                const sheet=doc.createElement('section'); sheet.className=`sheet ${page.landscape?'landscape':''}`;
                sheet.style.gridTemplateColumns=`repeat(${page.cols},${page.width}mm)`;
                sheet.style.gridAutoRows=`${page.height}mm`;
                for(const item of page.items) {const label=doc.createElement('div'); label.className='label'; label.append(doc.importNode(svg(item.template,item.record),true)); sheet.append(label);}
                doc.body.append(sheet);
            }
            openModal('tagPrintModal');
        } catch(error) { showToast(error.message,'error'); }
    }
    async function print() {
        const frame=document.getElementById('tagPrintFrame');
        if(!frame.contentDocument?.querySelector('.sheet')) return;
        await frame.contentDocument.fonts.ready;
        await Promise.all([...frame.contentDocument.querySelectorAll('image')].map(el=>new Promise(resolve=>{const img=new Image();img.onload=resolve;img.onerror=resolve;img.src=el.getAttribute('href');})));
        frame.contentWindow.focus(); frame.contentWindow.print();
    }
    function toggle(input) {
        const key=JSON.stringify([input.dataset.kind,input.dataset.tag]);
        if(input.checked) selected.set(key,{kind:input.dataset.kind,tag:input.dataset.tag}); else selected.delete(key);
        document.querySelectorAll('[data-selection-count]').forEach(e=>e.textContent=`${selected.size} selected`);
    }
    function selectAll() { document.querySelectorAll('input.tag-select').forEach(e=>{ e.checked=true;toggle(e); }); }
    function clear() {selected.clear();document.querySelectorAll('input.tag-select').forEach(e=>e.checked=false);document.querySelectorAll('[data-selection-count]').forEach(e=>e.textContent='0 selected');}
    function toolbar() {return `<div class="bulk-actions"><button class="btn btn-secondary" onclick="TagStudio.selectAll()">Select All Shown</button><button class="btn btn-secondary" onclick="TagStudio.clear()">Clear Selection</button><button class="btn btn-primary" onclick="TagStudio.printSelected()">Print Selected</button><span data-selection-count aria-live="polite">${selected.size} selected</span></div>`;}
    function checkbox(kind,tag) {return `<input class="tag-select" type="checkbox" aria-label="Select ${esc(tag)} for printing" data-kind="${kind}" data-tag="${esc(tag)}" onchange="TagStudio.toggle(this)" ${selected.has(JSON.stringify([kind,tag]))?'checked':''}>`;}
    function openEditor() {
        load(); editorAsset=null;active=templates[0].id;draft=clone(templates[0]); selectedElement=draft.elements[0]?.id;renderEditor();
    }
    function renderEditor() {
        const pane=document.getElementById('settingsPaneContainer');
        pane.innerHTML=`<div class="settings-pane studio"><h3>Tag Customizer</h3><p>Drag elements to move; drag the highlighted corner to resize. Arrow keys nudge the selection. Dimensions are in millimetres.</p>
        <div class="studio-tools"><select id="templateSelect" aria-label="Template">${templates.map(t=>`<option value="${esc(t.id)}" ${t.id===active?'selected':''}>${esc(t.name)}</option>`).join('')}</select><button data-command="new">New</button><button data-command="duplicate">Duplicate</button><button data-command="delete">Delete</button><button data-command="reset">Reset Changes</button><button data-command="defaults">Restore Default</button><button data-command="save">Save Template</button></div>
        <div class="studio-tools"><label>Name <input id="templateName" value="${esc(draft.name)}" maxlength="80"></label><label>Use for <select id="templateKind"><option value="workstation">Workstation</option><option value="peripheral">Peripheral</option></select></label><label>Size <select id="presetSize"><option value="custom">Custom</option><option value="a6">A6 · 105 × 148</option><option value="a7">A7 · 105 × 74</option></select></label><label>Width <input id="templateWidth" type="number" min="30" max="297" value="${draft.width}"></label><label>Height <input id="templateHeight" type="number" min="30" max="297" value="${draft.height}"></label><label>Background <input id="templateBackground" type="color" value="${color(draft.background,'#ffffff')}"></label></div>
        <div class="studio-tools">${['text','field','qr','logo','image'].map(type=>`<button data-add="${type}">Add ${type}</button>`).join('')}<input hidden id="studioImage" type="file" accept="image/png,image/jpeg,image/gif"><button data-command="preview">Print Preview</button></div>
        <label>Preview asset <select id="previewAsset"><option value="">Choose a real asset</option>${[...data.workstations.map(a=>['workstation',a.workstationTag]),...data.peripherals.map(a=>['peripheral',a.peripheralTag])].map(([kind,tag])=>`<option value="${esc(JSON.stringify([kind,tag]))}">${esc(tag)}</option>`).join('')}</select></label>
        <div class="studio-workspace"><div class="studio-stage-scroll"><div id="studioStage" tabindex="0" aria-label="Tag editor. Use arrow keys to move selected element."></div></div><aside id="studioInspector"></aside></div><p class="muted">Templates use the same renderer as printed tags. Standard tags scale proportionally to fit safe A4 printer margins.</p></div>`;
        pane.querySelector('#templateKind').value=draft.kind;
        pane.querySelector('#templateSelect').onchange=e=>{if(!confirm('Switch template and discard unsaved edits?')){e.target.value=active;return;}active=e.target.value;draft=clone(templates.find(t=>t.id===active));selectedElement=draft.elements[0]?.id;renderEditor();};
        for(const [id,key] of [['templateName','name'],['templateWidth','width'],['templateHeight','height'],['templateBackground','background'],['templateKind','kind']]) pane.querySelector('#'+id).onchange=e=>{draft[key]=['width','height'].includes(key)?Math.max(30,Math.min(297,number(e.target.value,105))):e.target.value;boundAll();draw();};
        pane.querySelector('#presetSize').onchange=e=>{if(e.target.value==='custom')return;draft.width=105;draft.height=e.target.value==='a6'?148:74;boundAll();renderEditor();};
        pane.querySelectorAll('[data-add]').forEach(b=>b.onclick=()=>add(b.dataset.add));
        pane.querySelectorAll('[data-command]').forEach(b=>b.onclick=()=>command(b.dataset.command));
        pane.querySelector('#previewAsset').onchange=e=>{editorAsset=e.target.value?asset(...JSON.parse(e.target.value)):null;draw();};
        pane.querySelector('#studioImage').onchange=async e=>{
            const file=e.target.files[0];if(!file)return;
            if(!['image/png','image/jpeg','image/gif'].includes(file.type)||file.size>512*1024)return showToast('Choose a PNG, JPG or GIF smaller than 512 KB','error');
            const reader=new FileReader();reader.onload=()=>add('image',reader.result);reader.readAsDataURL(file);
        };
        const stage=pane.querySelector('#studioStage');
        stage.onpointerdown=e=>{const group=e.target.closest('[data-element]');if(!group)return;selectedElement=group.dataset.element;const el=draft.elements.find(x=>x.id===selectedElement);const rect=stage.getBoundingClientRect();dragging={startX:e.clientX,startY:e.clientY,original:clone(el),scale:rect.width/draft.width,resize:e.target.hasAttribute('data-resize')};stage.setPointerCapture(e.pointerId);stage.focus();draw();};
        stage.onpointermove=e=>{if(!dragging)return;const el=draft.elements.find(x=>x.id===selectedElement);const dx=(e.clientX-dragging.startX)/dragging.scale,dy=(e.clientY-dragging.startY)/dragging.scale; if(dragging.resize){el.w=dragging.original.w+dx;el.h=dragging.original.h+dy;}else{el.x=dragging.original.x+dx;el.y=dragging.original.y+dy;}bound(el);draw();};
        stage.onpointerup=()=>dragging=null;stage.onpointercancel=()=>dragging=null;
        stage.onkeydown=e=>{const el=draft.elements.find(x=>x.id===selectedElement);if(!el)return;const moves={ArrowLeft:[-1,0],ArrowRight:[1,0],ArrowUp:[0,-1],ArrowDown:[0,1]};if(moves[e.key]){e.preventDefault();el.x+=moves[e.key][0]*(e.shiftKey?5:1);el.y+=moves[e.key][1]*(e.shiftKey?5:1);bound(el);draw();}};
        draw();
    }
    function bound(el) {el.w=Math.max(3,Math.min(draft.width,number(el.w,20)));el.h=Math.max(3,Math.min(draft.height,number(el.h,10)));el.x=Math.max(0,Math.min(draft.width-el.w,number(el.x)));el.y=Math.max(0,Math.min(draft.height-el.h,number(el.y)));}
    function boundAll(){draft.elements.forEach(bound);}
    function add(type,src) {if(type==='image'&&!src)return document.getElementById('studioImage').click();const el={id:crypto.randomUUID(),type,x:5,y:5,w:30,h:type==='qr'?30:12,fontSize:3.5,text:'Your text',field:'tag',src};draft.elements.push(el);selectedElement=el.id;bound(el);draw();}
    function draw() {
        const stage=document.getElementById('studioStage');stage.style.aspectRatio=`${draft.width}/${draft.height}`;
        try {stage.replaceChildren(svg(draft,editorAsset,true));}catch(e){showToast(e.message,'error');return;}
        const inspector=document.getElementById('studioInspector');const el=draft.elements.find(e=>e.id===selectedElement);
        inspector.innerHTML=`<label>Element<select id="elementList">${draft.elements.map(e=>`<option value="${esc(e.id)}" ${e.id===selectedElement?'selected':''}>${esc(e.type==='field'?e.field:e.type)}</option>`).join('')}</select></label>`;
        inspector.querySelector('select').onchange=e=>{selectedElement=e.target.value;draw();};
        if(!el)return;
        inspector.innerHTML+=`${['x','y','w','h','fontSize','padding','borderWidth'].map(k=>`<label>${({w:'Width',h:'Height',fontSize:'Font size',borderWidth:'Border',padding:'Padding'})[k]||k}<input data-prop="${k}" type="number" step="0.5" min="0" value="${number(el[k])}"></label>`).join('')}
          <label>Text<textarea data-prop="text">${esc(el.text || '')}</textarea></label><label>Asset field<select data-prop="field">${fields.map(f=>`<option ${el.field===f?'selected':''}>${f}</option>`).join('')}</select></label><label>Font<select data-prop="font">${['Arial','Georgia','Courier New'].map(f=>`<option ${el.font===f?'selected':''}>${f}</option>`).join('')}</select></label><label>Text alignment<select data-prop="align">${['left','center','right'].map(f=>`<option ${el.align===f?'selected':''}>${f}</option>`).join('')}</select></label><label><input data-prop="bold" type="checkbox" ${el.bold?'checked':''}> Bold</label>${['color','background','borderColor'].map(k=>`<label>${k}<input data-prop="${k}" type="color" value="${color(el[k],k==='background'?'#ffffff':'#111827')}"></label>`).join('')}<button id="centerElement">Center on tag</button><button id="removeElement">Remove element</button>`;
        inspector.querySelector('#elementList').onchange=e=>{selectedElement=e.target.value;draw();};
        inspector.querySelectorAll('[data-prop]').forEach(input=>input.onchange=()=>{el[input.dataset.prop]=input.type==='checkbox'?input.checked:input.type==='number'?number(input.value):input.value;bound(el);draw();});
        inspector.querySelector('#centerElement').onclick=()=>{el.x=(draft.width-el.w)/2;draw();};
        for(const [label,x,y] of [['Left',0,null],['Right',draft.width-el.w,null],['Top',null,0],['Bottom',null,draft.height-el.h]]) {
            const button=document.createElement('button');button.textContent=`Align ${label}`;button.onclick=()=>{if(x!==null)el.x=x;if(y!==null)el.y=y;draw();};inspector.append(button);
        }
        inspector.querySelector('#removeElement').onclick=()=>{draft.elements=draft.elements.filter(e=>e!==el);selectedElement=draft.elements[0]?.id;draw();};
    }
    async function command(action) {
        if(action==='preview')return editorAsset?preview([editorAsset],draft):showToast('Choose a real asset for print preview','error');
        if(action==='reset'){draft=clone(templates.find(t=>t.id===active));selectedElement=draft.elements[0]?.id;return renderEditor();}
        if(action==='defaults'){if(!confirm('Replace this draft with the default layout?'))return;draft={...TagLayout.defaults(draft.kind),id:active,name:draft.name};return renderEditor();}
        if(action==='new'||action==='duplicate'){draft=action==='new'?TagLayout.defaults(draft.kind):clone(draft);draft.id=crypto.randomUUID();draft.name=action==='new'?'New template':draft.name+' copy';active=draft.id;templates.push(clone(draft));return renderEditor();}
        if(action==='delete'){if(templates.length===1)return showToast('Keep at least one template','error');if(!confirm('Delete this template?'))return;const remaining=templates.filter(t=>t.id!==active);try{await api('/api/settings',{method:'POST',body:{tagTemplates:JSON.stringify(remaining)}});data.settings.tagTemplates=JSON.stringify(remaining);openEditor();}catch(_){}return;}
        if(action==='save'){
            if(!draft.name.trim()||!draft.elements.length)return showToast('Provide a name and at least one element','error');
            const updated=templates.map(t=>t.id===active?clone(draft):t);
            const payload={tagTemplates:JSON.stringify(updated),[draft.kind==='workstation'?'workstationTemplate':'peripheralTemplate']:draft.id};
            try {await api('/api/settings',{method:'POST',body:payload});Object.assign(data.settings,payload);templates=updated;showToast('Template saved and selected for printing','success');}catch(_){}
        }
    }
    return { openEditor, checkbox, toolbar, toggle, selectAll, clear, print,
        printOne:(tag,kind)=>preview([asset(kind,tag)]), printSelected:()=>preview([...selected.values()].map(s=>asset(s.kind,s.tag))) };
})();
