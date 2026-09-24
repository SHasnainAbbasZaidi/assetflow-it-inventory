(function (root) {
    'use strict';
    const defaults = kind => {
        const small=kind==='peripheral';
        return {id:`compact-${kind}`,name:small?'Peripheral · 93 × 30 mm':'Device Details · 93 × 65 mm',kind,width:93,height:small?30:65,background:'#ffffff',elements:[
            {id:'title',type:'text',text:small?'Peripheral Tag':'Device Details',x:3,y:2,w:62,h:6,fontSize:3.3,bold:true,color:'#2980b9'},
            {id:'qr',type:'qr',x:69,y:3,w:21,h:21},
            {id:'tag',type:'field',field:'tagLabel',x:3,y:9,w:63,h:8,fontSize:2.8,bold:true},
            {id:small?'purchase':'person',type:'field',field:small?'purchaseLabel':'personLabel',x:3,y:18,w:63,h:9,fontSize:2.8},
            ...(!small?[{id:'specs',type:'field',field:'specs',x:3,y:30,w:87,h:31,fontSize:2.8}]:[])
        ]};
    };
    function paginate(items) {
        const groups = new Map();
        for (const item of items) {
            const t = item.template;
            if (!(t.width > 0 && t.height > 0 && t.width <= 1000 && t.height <= 1000)) throw Error('Invalid tag dimensions');
            const key = `${t.width}:${t.height}`;
            if (!groups.has(key)) groups.set(key, []);
            groups.get(key).push(item);
        }
        const pages = [];
        for (const group of groups.values()) {
            const { width, height } = group[0].template;
            // Safe 10 mm margins, 4 mm gutters; keep the exact tag aspect ratio.
            let best;
            for (const landscape of [false, true]) {
                const pw = landscape ? 277 : 190, ph = landscape ? 190 : 277;
                for (let cols=1; cols<=4; cols++) for (let rows=1; rows<=8; rows++) {
                    const scale = Math.min(1, (pw-(cols-1)*4)/(cols*width), (ph-(rows-1)*4)/(rows*height));
                    if (scale < 1) continue;
                    const score = cols*rows;
                    if (!best || score > best.capacity || (score === best.capacity && scale > best.scale)) best = { landscape, cols, rows, scale, capacity:score };
                }
            }
            if(!best) throw Error('Tag is larger than the printable A4 area. Choose a smaller template.');
            for (let i=0; i<group.length; i+=best.capacity) pages.push({ ...best, width:width*best.scale, height:height*best.scale, items:group.slice(i,i+best.capacity) });
        }
        return pages;
    }
    function search(records, query, limit=40) {
        const q = String(query || '').trim().toLocaleLowerCase();
        if (!q) return [];
        const result = [];
        for (const record of records) {
            const matches = Object.entries(record.fields).filter(([,v]) => String(v || '').toLocaleLowerCase().includes(q)).map(([key])=>key);
            if (matches.length) result.push({ ...record, matches });
            if (result.length === limit) break;
        }
        return result;
    }
    const api = { defaults, paginate, search };
    if (typeof module !== 'undefined') module.exports = api;
    else root.TagLayout = api;
})(typeof window === 'undefined' ? globalThis : window);
