(function (root) {
    'use strict';
    const defaults = kind => {
        const small = kind === 'peripheral';
        const elements = [
            { id:'logo', type:'logo', x:6, y:5, w:15, h:12 },
            { id:'company', type:'field', field:'companyName', x:24, y:5, w:75, h:8, fontSize:4, bold:true },
            { id:'address', type:'field', field:'companyAddress', x:24, y:14, w:75, h:8, fontSize:2.6 },
            { id:'tag', type:'field', field:'tag', x:6, y:26, w:60, h:12, fontSize:5, bold:true },
            { id:'qr', type:'qr', x:70, y:27, w:29, h:29 },
            { id:'device', type:'field', field:'device', x:6, y:40, w:59, h:10, fontSize:3.5 },
            { id:'person', type:'field', field:'person', x:6, y:52, w:59, h:10, fontSize:3.2 }
        ];
        if (!small) elements.push({ id:'specs', type:'field', field:'specs', x:6, y:72, w:93, h:62, fontSize:3.5 });
        return { id:`default-${kind}`, name:small ? 'Peripheral · A7' : 'Workstation · A6', kind, width:105, height:small ? 74 : 148, background:'#ffffff', elements };
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
                    if (scale < 0.85 && cols*rows > 1) continue;
                    const score = cols*rows;
                    if (!best || score > best.capacity || (score === best.capacity && scale > best.scale)) best = { landscape, cols, rows, scale, capacity:score };
                }
            }
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
