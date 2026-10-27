const fs=require('fs');
const d=JSON.parse(fs.readFileSync('game/data/story.json','utf8'));
const out=[];
// 1) main/closing line speakers
for(const id of ['ch1.report.student.success','ch1.report.student.acceptFail','ch1.student.B1','ch1.student.N1']){
  const e=d.events.find(x=>x.id===id); if(!e){out.push(id+' MISSING');continue;}
  out.push('EVENT '+id+' type='+e.type+' order='+JSON.stringify(e.sectionOrder));
  for(const s of ['main','partner','closing','branch']){
    const arr=e.sections[s]||[];
    out.push('  '+s+' ('+arr.length+'): '+arr.map(i=>i.kind==='line'?(i.speaker+': '+i.text.slice(0,18)):('[text] '+String(i.text).slice(0,18))).join(' | '));
  }
}
// 2) narration lengths for reality + ending + prepFail
out.push('\n-- narration item lengths --');
const narr=[];
for(const e of d.events){ const a=e.sections.narration||[]; if(a.length) narr.push({id:e.id,type:e.type,n:a.length,lens:a.map(i=>String(i.text).length),sample:a[0].text}); }
out.push('events with narration='+narr.length+' ; items total='+narr.reduce((s,x)=>s+x.n,0));
out.push('max len='+Math.max(...narr.flatMap(x=>x.lens))+' ; >14 count='+narr.flatMap(x=>x.lens).filter(l=>l>14).length);
for(const x of narr.filter(x=>x.lens.some(l=>l>14))) out.push('  OVER14 '+x.id+' ('+x.type+') '+x.lens.join(',')+' :: '+x.sample);
// 3) branch sections: total events, kinds
const br=d.events.filter(e=>e.sections.branch&&e.sections.branch.length);
out.push('\n-- branch sections --');
out.push('events with branch='+br.length+' types='+JSON.stringify([...new Set(br.map(e=>e.type))]));
out.push('ids='+br.map(e=>e.id).join(', '));
// 4) staging item char/句 stats
const st=[];for(const e of d.events){const a=e.sections.staging||[];for(const i of a)st.push({id:e.id,len:String(i.text).length,sent:String(i.text).split(/[。！？]/).filter(Boolean).length,kind:i.kind});}
out.push('\n-- staging --'); out.push('items='+st.length+' len range='+Math.min(...st.map(x=>x.len))+'..'+Math.max(...st.map(x=>x.len))+' sent range='+Math.min(...st.map(x=>x.sent))+'..'+Math.max(...st.map(x=>x.sent))+' kinds='+JSON.stringify([...new Set(st.map(x=>x.kind))]));
// 5) duplicate speaker within main/closing
out.push('\n-- duplicate same-speaker lines in main/closing --');
let dup=0;
for(const e of d.events){for(const s of ['main','closing']){const a=(e.sections[s]||[]).filter(i=>i.kind==='line');const c={};for(const i of a)c[i.speaker]=(c[i.speaker]||0)+1;for(const k in c)if(c[k]>1){dup++;if(dup<=8)out.push('  '+e.id+'/'+s+' '+k+'x'+c[k]);}}}
out.push('dup groups='+dup);
fs.writeFileSync('_build/tmp_lead_shape.cjs.log',out.join('\n'),'utf8');
console.log(out.join('\n'));
