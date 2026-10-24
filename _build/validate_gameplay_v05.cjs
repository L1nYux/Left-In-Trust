// Offline executable design model. No UI, filesystem save system, or player simulation.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const data = JSON.parse(fs.readFileSync(path.join(root, 'docs/首批内容.json'), 'utf8'));
const defs = Object.fromEntries(data.cards.map(c => [c.id, c]));
const enemyDefs = Object.fromEntries(data.enemies.map(e => [e.id, e]));
const clone = x => JSON.parse(JSON.stringify(x));
const tests = [];
function test(name, f) { f(); tests.push(name); }
function reject(condition, message) { if (condition) throw new Error(message); }
function rng(s) { let x = s.seed >>> 0 || 1; x ^= x << 13; x ^= x >>> 17; x ^= x << 5; s.seed = x >>> 0; return s.seed / 4294967296; }
function shuffle(s, cards) { for (let i=cards.length-1; i>0; i--) { const j=Math.floor(rng(s)*(i+1)); [cards[i],cards[j]]=[cards[j],cards[i]]; } return cards; }
function deck(role) { const r=data.roles.find(r=>r.id===role); return ['A','A','A','D','D','D','H','H','R',r.cards[0],r.cards[0],r.cards[1]].map((code,i)=>({id:`${role}-${i}`,code,upgraded:false})); }
function run(ids=['GPT'], seed=1) { return {id:`run-${seed}`,seed,stage:'employee',difficulty:0,accounts:Object.fromEntries(ids.map(id=>[id,{token:12,max:12}])),deck:deck(ids[0]),wallet:0,nodes:{},services:{},profile:{collection:{},facts:{},unlocked:['GPT'],regularClear:false,maxDifficulty:0},ended:false}; }
function card(c) { const d=clone(defs[c.code]); if(c.upgraded) for(const [k,v] of Object.entries(d.upgrade||{})) d[k]=(d[k]||0)+v; return d; }
function start(r,id,ids,enemyId,seed=1) {
  reject(r.ended || r.nodes[id], 'run_or_node_finished');
  reject(!ids.length || ids.length>3 || new Set(ids).size!==ids.length || ids.some(id=>!r.accounts[id] || r.accounts[id].token<=0),'invalid_lineup');
  const e=clone(enemyDefs[enemyId]); reject(!e,'unknown_enemy');
  const s={id,seed,turn:0,phase:'between',result:'ongoing',accounts:clone(r.accounts),difficulty:r.difficulty,stage:r.stage,enemy:e,hp:e.hp,enemyGuard:0,pending:0,feedbackIndex:0,feedback:[],actors:ids.map(id=>({id,online:true,acted:false,shield:0,streak:0,counter:false,rice:0,protected:[]})),draw:clone(r.deck.filter(c=>!defs[c.code].owner || ids.includes(defs[c.code].owner))),hand:[],discard:[],consumed:[],sealed:[],intents:[],log:[]};
  s.feedback=[...ids,...Object.keys(r.accounts).filter(x=>!ids.includes(x))];
  s.total=s.draw.length; shuffle(s,s.draw); invariant(s); r.started=true; return s;
}
function actor(s,id) { const a=s.actors.find(a=>a.id===id); reject(!a,'not_in_lineup'); return a; }
function invariant(s) { const cards=[...s.draw,...s.hand,...s.discard,...s.consumed,...s.sealed]; assert.equal(cards.length,s.total); assert.equal(new Set(cards.map(c=>c.id)).size,s.total); for(const a of Object.values(s.accounts)) assert(a.token>=0 && a.token<=a.max); }
function begin(s) {
  reject(s.phase!=='between'||s.result!=='ongoing','invalid_begin'); s.turn++;s.phase='player';s.enemyGuard=0;
  for(const a of s.actors) {a.acted=false;a.shield=0;a.protected=[];}
  let amounts=[...s.enemy.pattern[(s.turn-1)%s.enemy.pattern.length]];
  const k=amounts.findIndex(x=>x>0); let notice=null;
  if(k>=0) {
    amounts[k]+=Math.floor((s.turn-1)/4)+Math.floor(s.difficulty/2)+s.pending;s.pending=0;
    if(s.enemy.hidden) {
      if(s.turn%2===1) {if(s.stage==='employee') amounts[k]++; else if(s.stage==='student' && amounts.length===1) amounts=[Math.ceil(amounts[0]/2),Math.floor(amounts[0]/2)].filter(Boolean);}
      else {const who=s.feedback[s.feedbackIndex++%s.feedback.length];
        if(who==='GPT')s.enemyGuard=2;
        else if(who==='Claude')amounts.push(1);
        else if(who==='DeepSeek'){s.pending=2;notice='下一有伤害回合首段 +2';}
      }
    }
  }
  const offset=(s.turn-1)%s.actors.length;
  const target=[...s.actors.slice(offset),...s.actors.slice(0,offset)].find(a=>a.online).id;
  s.intents=amounts.filter(x=>x>0).map(raw=>({target,raw}));s.notice=notice;
  while(s.hand.length<5) {if(!s.draw.length) {s.draw=shuffle(s,s.discard.splice(0));}if(!s.draw.length)break;s.hand.push(s.draw.shift());}
  invariant(s);
}
function act(s,id,cardId,targetId=id) {
  const a=actor(s,id);reject(s.phase!=='player'||s.result!=='ongoing'||!a.online||a.acted,'action_unavailable');
  const basic=['basic','guard'].includes(cardId);
  const c=basic?null:s.hand.find(c=>c.id===cardId);reject(!basic&&!c,'not_in_hand');
  const d=basic?(cardId==='basic'?{kind:'attack',cost:0,damage:3}:{kind:'guard',cost:0,shield:3,target:'self'}):card(c);
  reject(d.owner&&d.owner!==id,'wrong_owner');
  const target=actor(s,targetId);
  reject(!target.online,'offline_target');
  reject((d.target==='self'||(basic&&cardId==='guard')||d.kind==='attack')&&targetId!==id,'self_only');
  reject(d.kind==='transfer'&&(targetId===id||s.accounts[targetId].max-s.accounts[targetId].token<2),'bad_transfer');
  reject(d.kind==='heal'&&s.accounts[targetId].token===s.accounts[targetId].max,'no_heal');
  reject(s.accounts[id].token-d.cost<1,'personal_payment');
  // All checks above precede all mutation.
  let damage=d.damage||0;
  if(id==='GPT') {if(!basic&&d.kind==='attack'){damage+=a.streak*2+(a.streak===2?(d.fullStreakBonus||0):0);a.streak=Math.min(2,a.streak+1);}else a.streak=0;}
  if(id==='Claude'&&d.kind==='attack'&&a.counter){damage+=4;a.counter=false;}
  if(id==='DeepSeek'&&!basic&&d.kind==='attack') {if(d.cashRice){damage+=a.rice*2;a.rice=0;}else if(d.cost>=2&&a.rice===3){damage+=6;a.rice=0;}}
  s.accounts[id].token-=d.cost;
  if(d.heal)s.accounts[targetId].token=Math.min(s.accounts[targetId].max,s.accounts[targetId].token+d.heal);
  if(d.shield){target.shield+=d.shield;a.protected.push(targetId);}
  if(d.riceGain)a.rice=Math.min(3,a.rice+d.riceGain);
  if(damage>0){const absorbed=Math.min(damage,s.enemyGuard);damage-=absorbed;s.enemyGuard=0;s.hp=Math.max(0,s.hp-damage);}
  if(c){s.hand.splice(s.hand.indexOf(c),1);(d.consume?s.consumed:s.discard).push(c);}
  a.acted=true;
  if(s.hp===0)s.result='win';
  invariant(s);return damage;
}
function hit(s,id,raw){const a=actor(s,id);if(!a.online)return {target:id,absorbed:0,lost:0,skipped:true};const absorbed=Math.min(raw,a.shield);a.shield-=absorbed;const lost=Math.min(s.accounts[id].token,raw-absorbed);s.accounts[id].token-=lost;
  if(s.accounts[id].token===0){a.online=false;a.shield=0;a.streak=0;a.counter=false;a.rice=0;a.protected=[];for(const zone of ['draw','hand','discard']){const keep=[];for(const c of s[zone])(defs[c.code].owner===id?s.sealed:keep).push(c);s[zone]=keep;}if(s.actors.every(a=>!a.online))s.result='loss';}
  invariant(s);return {target:id,absorbed,lost,skipped:false};}
function finish(s){reject(s.phase!=='player','invalid_finish');s.phase='enemy';const events=[];
  if(s.result==='ongoing')for(const i of s.intents){events.push(hit(s,i.target,i.raw));if(s.result!=='ongoing')break;}
  for(const a of s.actors){if(a.id==='GPT'&&!a.acted)a.streak=0;if(s.result==='ongoing'&&a.online){if(a.id==='Claude'&&events.some(e=>a.protected.includes(e.target)&&e.absorbed>0))a.counter=true;if(a.id==='DeepSeek')a.rice=Math.min(3,a.rice+1);}a.shield=0;}
  s.discard.push(...s.hand.splice(0));s.phase='between';s.log.push({turn:s.turn,hp:s.hp,balances:Object.fromEntries(Object.entries(s.accounts).map(([id,a])=>[id,a.token])),events,result:s.result});invariant(s);}
function settle(r,s,{task=null,terminal=false,variant='main'}={}){
  reject(s.result==='ongoing','unfinished');const outcome=s.result;
  if(r.nodes[s.id]){reject(r.nodes[s.id]!==outcome,'conflicting_result');return false;}
  reject(r.ended,'run_ended');r.accounts=clone(s.accounts);r.nodes[s.id]=outcome;
  if(outcome==='win'){for(const a of Object.values(r.accounts))if(a.token>0)a.token=Math.min(a.max,a.token+3);r.wallet+=s.enemy.boss?8:4;if(terminal){r.profile.regularClear=true;if(r.difficulty===r.profile.maxDifficulty)r.profile.maxDifficulty=Math.min(3,r.difficulty+1);}}
  else r.ended=true;
  if(task){const key=`${r.stage}/${task}/${outcome}/${variant}`;r.profile.collection[key]??={firstRun:r.id};const facts=data.tasks.find(t=>t.id===task)?.facts||[];if(outcome==='win'){r.profile.facts[r.stage]??=[];r.profile.facts[r.stage]=[...new Set([...r.profile.facts[r.stage],...facts])];}}
  return true;
}
function service(r,node,kind,id){reject(r.ended||r.services[node],'service_used');const a=r.accounts[id];reject(!a,'bad_target');reject(a.token===a.max,'no_heal');const cost=kind==='shop'?6:0;reject(r.wallet<cost,'no_money');r.wallet-=cost;a.token=Math.min(a.max,a.token+(kind==='shop'?4:6));r.services[node]=kind;}
function rewardPool(r){return data.cards.filter(c=>(!c.owner||r.accounts[c.owner])&&(!c.minRoster||Object.keys(r.accounts).length>=c.minRoster)&&(!c.maxCopies||r.deck.filter(x=>x.code===c.id).length<c.maxCopies)).map(c=>c.id);}
function candidates(r){return data.roles.map(x=>x.id).filter(x=>!r.accounts[x]);}
function recruit(r,id,node){reject(r.ended||r.services[node]||!candidates(r).includes(id),'invalid_recruit');r.accounts[id]={token:12,max:12};for(const [i,code]of data.roles.find(x=>x.id===id).cards.entries())r.deck.push({id:`${node}-${id}-${i}`,code,upgraded:false});r.profile.unlocked=[...new Set([...r.profile.unlocked,id])];r.services[node]='recruit';}
function upgrade(r,id){const c=r.deck.find(c=>c.id===id);reject(!c||c.upgraded,'invalid_upgrade');c.upgraded=true;}
function removeCard(r,id){reject(r.deck.length<=8,'min_deck');const i=r.deck.findIndex(c=>c.id===id);reject(i<0,'missing_card');r.deck.splice(i,1);}
function selectTask(stage,chapter,u,filter=()=>true){const valid=data.tasks.filter(t=>t.stages.includes(stage)&&t.chapter===chapter);reject(!valid.length,'no_stage_content');const pool=valid.filter(filter);return (pool.length?pool[Math.min(pool.length-1,Math.floor(u*pool.length))]:valid.find(t=>t.fallback)).id;}
function finalBoss(stage,u,challenge){if(challenge&&u<data.challenge.stageBossProbability)return `stage_${stage}`;return 'recipient';}
function hidden(clear,D,T=1){return clear&&D>T;}
function setDifficulty(r,D){reject(r.started||r.ended||Object.keys(r.nodes).length>0,'difficulty_started');reject(!Number.isInteger(D)||D<0||D>r.profile.maxDifficulty||D>3,'difficulty_locked');r.difficulty=D;}
function ending(profile,stage){return ['work_value','someone_waiting'].every(f=>(profile.facts[stage]||[]).includes(f));}
function legalActions(s,id){const options=[];for(const c of ['basic','guard',...s.hand.map(x=>x.id)])for(const t of s.actors.filter(a=>a.online)){const b=clone(s);try{act(b,id,c,t.id);options.push({c,t:t.id,s:b});}catch{}}return options;}
function choose(s,mode){let best=null,bestScore=-Infinity;
  function search(b,index,plan){if(index>=b.actors.length||b.result!=='ongoing'){const end=clone(b);finish(end);const tokens=Object.values(end.accounts).reduce((v,a)=>v+a.token,0);const active=end.actors.filter(a=>a.online).length;const damage=s.hp-end.hp;const buffs=end.actors.reduce((v,a)=>v+a.streak*1.2+a.rice*1.5+Number(a.counter)*3,0);
      const score=end.result==='win'?10000+tokens:(end.result==='loss'?-10000:damage*(mode==='rush'?3:1.25)+tokens*2+active*8+buffs);if(score>bestScore){bestScore=score;best=plan;}return;}
    const a=b.actors[index];if(!a.online){search(b,index+1,plan);return;}for(const o of legalActions(b,a.id))search(o.s,index+1,[...plan,[a.id,o.c,o.t]]);
  }search(s,0,[]);return best||[];}
function play(r,id,ids,enemy,seed,mode='budget'){const s=start(r,id,ids,enemy,seed);while(s.result==='ongoing'&&s.turn<40){begin(s);const plan=choose(s,mode);for(const [a,c,t]of plan){if(s.result!=='ongoing')break;act(s,a,c,t);}finish(s);}return s;}

test('十二卡种与升级定义有效',()=>{assert.equal(data.cards.length,12);assert.equal(new Set(data.cards.map(c=>c.id)).size,12);for(const c of data.cards)assert(c.cost>=0&&c.upgrade);for(const r of data.roles){assert.equal(deck(r.id).length,12);assert.equal(deck(r.id).filter(c=>c.code==='R').length,1);}});
test('四任务两阶段无空池且随机可变',()=>{for(const stage of ['student','employee'])for(const ch of [1,2]){assert.notEqual(selectTask(stage,ch,0),selectTask(stage,ch,.99));assert(selectTask(stage,ch,.5,()=>false));}});
function prepared(ids=['GPT'],enemy='submit'){const r=run(ids);const s=start(r,'test',ids,enemy);begin(s);s.draw.push(...s.hand.splice(0));s.hand=s.draw.splice(0);return {r,s};}
function find(s,code){return s.hand.find(c=>c.code===code).id;}
test('个人支付不足不借队友且非法操作原子拒绝',()=>{const {s}=prepared(['GPT','Claude']);s.accounts.GPT.token=1;const before=clone(s);assert.throws(()=>act(s,'GPT',find(s,'A')),/payment/);assert.deepEqual(s,before);});
test('满血补给不消耗牌或行动',()=>{const{s}=prepared();const before=clone(s);assert.throws(()=>act(s,'GPT',find(s,'R')),/no_heal/);assert.deepEqual(s,before);});
test('专属归属与每人一次行动',()=>{const {s}=prepared(['GPT','Claude']);assert.throws(()=>act(s,'Claude',find(s,'G1')),/owner/);act(s,'GPT',find(s,'A'));assert.throws(()=>act(s,'GPT','basic'),/unavailable/);});
test('定向防护逐段消耗且不保护施加者',()=>{const {s}=prepared(['GPT','Claude']);act(s,'Claude',find(s,'D'),'GPT');assert.equal(actor(s,'Claude').shield,0);assert.equal(hit(s,'GPT',3).absorbed,3);assert.equal(hit(s,'GPT',3).absorbed,1);assert.equal(s.accounts.GPT.token,10);});
test('锁定目标下线不转火且专属牌封存',()=>{const {s}=prepared(['GPT','Claude']);s.accounts.GPT.token=1;const before=s.accounts.Claude.token;hit(s,'GPT',1);assert.equal(s.sealed.length,3);assert(hit(s,'GPT',9).skipped);assert.equal(s.accounts.Claude.token,before);assert.equal(s.result,'ongoing');});
test('群攻展开后独立扣各目标',()=>{const {s}=prepared(['GPT','Claude']);s.intents=[{target:'GPT',raw:3},{target:'Claude',raw:3}];act(s,'GPT',find(s,'D'),'GPT');finish(s);assert.equal(s.accounts.GPT.token,12);assert.equal(s.accounts.Claude.token,9);});
test('全上场失败时替补不救场不获胜后回复',()=>{const r=run(['GPT','Claude']);const s=start(r,'dead',['GPT'],'missing');begin(s);hit(s,'GPT',12);assert.equal(s.result,'loss');settle(r,s);assert.equal(r.accounts.Claude.token,12);assert.equal(r.wallet,0);assert(r.ended);});
test('胜利立即停手且不受敌方后续攻击',()=>{const{s}=prepared();s.hp=3;act(s,'GPT','basic');const before=s.accounts.GPT.token;assert.throws(()=>act(s,'GPT',find(s,'R')),/unavailable/);finish(s);assert.equal(s.accounts.GPT.token,before);});
test('转交守恒与目标限制',()=>{const {s}=prepared(['GPT','Claude']);s.hand.push({id:'transfer',code:'T',upgraded:false});s.total++;s.accounts.GPT.token=3;s.accounts.Claude.token=7;assert.throws(()=>act(s,'GPT','transfer','GPT'),/transfer/);act(s,'GPT','transfer','Claude');assert.deepEqual([s.accounts.GPT.token,s.accounts.Claude.token],[1,9]);});
test('补给消耗且奖励池不能增加第二份',()=>{const {r,s}=prepared();s.accounts.GPT.token=5;act(s,'GPT',find(s,'R'));assert.equal(s.consumed.length,1);assert(!rewardPool(r).includes('R'));assert(!rewardPool(r).includes('T'));finish(s);begin(s);assert(!s.hand.some(c=>c.code==='R'));});
test('GPT基础攻击断连击',()=>{const{s}=prepared();actor(s,'GPT').streak=2;assert.equal(act(s,'GPT','basic'),3);assert.equal(actor(s,'GPT').streak,0);});
test('Claude实际挡伤得到反击，基本攻击可兑现',()=>{const {s}=prepared(['Claude']);act(s,'Claude',find(s,'C1'));finish(s);assert(actor(s,'Claude').counter);begin(s);assert.equal(act(s,'Claude','basic'),7);assert(!actor(s,'Claude').counter);});
test('Claude施盾后下线仍保留队友防护，自己无新反击',()=>{const {s}=prepared(['Claude','GPT']);act(s,'Claude',find(s,'C1'),'GPT');hit(s,'Claude',12);assert.equal(hit(s,'GPT',5).absorbed,5);assert(!actor(s,'Claude').counter);});
test('DeepSeek主动蓄力与满层时点',()=>{const{s}=prepared(['DeepSeek']);act(s,'DeepSeek',find(s,'S1'));finish(s);assert.equal(actor(s,'DeepSeek').rice,2);begin(s);act(s,'DeepSeek','guard');finish(s);assert.equal(actor(s,'DeepSeek').rice,3);});
test('DeepSeek提前兑现不双算满层，普通强牌仍满层加六',()=>{for(const [code,want]of [['S2',14],['H',16]]){const{s}=prepared(['DeepSeek']);actor(s,'DeepSeek').rice=3;assert.equal(act(s,'DeepSeek',find(s,code)),want);assert.equal(actor(s,'DeepSeek').rice,0);}});
test('自然恢复含替补、不复起、下一战不回满',()=>{const {r,s}=prepared(['GPT','Claude','DeepSeek']);s.accounts.GPT.token=4;s.accounts.Claude.token=8;s.accounts.DeepSeek.token=0;s.hp=3;act(s,'GPT','basic');finish(s);settle(r,s);assert.deepEqual(Object.values(r.accounts).map(a=>a.token),[7,11,0]);assert.equal(start(r,'next',['GPT'],'missing').accounts.GPT.token,7);assert.throws(()=>start(r,'again',['DeepSeek'],'missing'),/lineup/);});
test('重载结算去重与同节点冲突拒绝',()=>{const {r,s}=prepared();s.hp=3;act(s,'GPT','basic');finish(s);settle(r,s,{task:'report'});const restored=clone(r);assert(!settle(restored,s,{task:'report'}));assert.deepEqual(restored,r);const bad=clone(s);bad.result='loss';assert.throws(()=>settle(restored,bad),/conflicting/);});
test('休息复起限次、商店失败不扣钱',()=>{const r=run();r.accounts.GPT.token=0;service(r,'rest','rest','GPT');assert.equal(r.accounts.GPT.token,6);assert.throws(()=>service(r,'rest','rest','GPT'),/used/);const before=clone(r);assert.throws(()=>service(r,'shop','shop','GPT'),/money/);assert.deepEqual(r,before);r.wallet=6;service(r,'shop','shop','GPT');assert.equal(r.accounts.GPT.token,10);assert.equal(r.wallet,0);});
test('招募未解锁角色可达且旧钱包不重置',()=>{const r=run();r.accounts.GPT.token=4;assert(candidates(r).includes('Claude'));recruit(r,'Claude','recruit');assert(r.profile.unlocked.includes('Claude'));assert.equal(r.accounts.GPT.token,4);assert.equal(r.accounts.Claude.token,12);assert(!candidates(r).includes('Claude'));});
test('升级仅一次与最少八张删卡边界',()=>{const r=run();upgrade(r,r.deck[0].id);assert.throws(()=>upgrade(r,r.deck[0].id),/upgrade/);assert.equal(card(r.deck[0]).damage,8);while(r.deck.length>8)removeCard(r,r.deck.at(-1).id);assert.throws(()=>removeCard(r,r.deck[0].id),/min_deck/);});
test('收藏不同尝试不重复、不同阶段分别收藏',()=>{const r=run();for(let i=0;i<3;i++){const s=start(r,`b${i}`,['GPT'],'submit');s.result='win';settle(r,s,{task:'report'});}assert.equal(Object.keys(r.profile.collection).length,1);r.stage='student';const s=start(r,'b4',['GPT'],'submit');s.result='win';settle(r,s,{task:'report'});assert.equal(Object.keys(r.profile.collection).length,2);});
test('主要结局纯成功可达且不能混拼阶段',()=>{const r=run();r.profile.facts={employee:['work_value'],student:['someone_waiting']};assert(!ending(r.profile,'employee'));r.profile.facts.employee.push('someone_waiting');assert(ending(r.profile,'employee'));});
test('隐藏阈值严格大于且阶段关底不影响触发',()=>{assert(!hidden(false,3));assert(!hidden(true,1));assert(hidden(true,2));for(const stage of ['student','employee']){assert.equal(finalBoss(stage,.1,true),`stage_${stage}`);assert.equal(finalBoss(stage,.9,true),'recipient');assert.equal(finalBoss(stage,.1,false),'recipient');for(const u of [.1,.9]){assert(finalBoss(stage,u,true));assert(hidden(true,2));}}});
test('隐藏失败保留普通成果与下一档解锁',()=>{const {r,s}=prepared();r.difficulty=2;r.profile.maxDifficulty=2;s.result='win';settle(r,s,{task:'report',terminal:true});const before=clone(r.profile);const h=start(r,'hidden',['GPT'],'hidden');h.result='loss';h.accounts.GPT.token=0;settle(r,h,{task:'hidden'});assert.equal(r.profile.maxDifficulty,3);for(const k of Object.keys(before.collection))assert(r.profile.collection[k]);assert(r.profile.regularClear);});
test('隐藏阶段与队伍会改变脚本但出牌不改预告',()=>{const a=run(['GPT']);a.stage='student';const b=clone(a);b.stage='employee';const x=start(a,'h1',['GPT'],'hidden'),y=start(b,'h1',['GPT'],'hidden');begin(x);begin(y);assert.notDeepEqual(x.intents,y.intents);const locked=clone(y.intents);act(y,'GPT','guard');assert.deepEqual(y.intents,locked);const z=run(['DeepSeek']);const hz=start(z,'h2',['DeepSeek'],'hidden');begin(hz);act(hz,'DeepSeek','guard');finish(hz);begin(hz);assert.equal(hz.pending,2);});
test('同种子牌序及战中JSON往返确定',()=>{const r=run();const a=start(r,'a',['GPT'],'missing',123),b=start(r,'b',['GPT'],'missing',123);begin(a);begin(b);assert.deepEqual(a.hand,b.hand);const copy=clone(a);act(a,'GPT','guard');act(copy,'GPT','guard');finish(a);finish(copy);assert.deepEqual(a,copy);});
test('持续基础防御不能无限拖延',()=>{const r=run();const s=start(r,'turtle',['GPT'],'submit');while(s.result==='ongoing'&&s.turn<40){begin(s);act(s,'GPT','guard');finish(s);}assert.equal(s.result,'loss');});
test('难度只能开局选已开放档',()=>{const r=run();assert.throws(()=>setDifficulty(r,2),/locked/);assert.throws(()=>setDifficulty(r,-1),/locked/);r.profile.regularClear=true;r.profile.maxDifficulty=2;setDifficulty(r,2);assert.equal(r.difficulty,2);start(r,'first',['GPT'],'missing');assert.throws(()=>setDifficulty(r,0),/started/);assert.equal(r.difficulty,2);});
test('白饭提前一层兑现有独立收益',()=>{const{s}=prepared(['DeepSeek']);actor(s,'DeepSeek').rice=1;assert.equal(act(s,'DeepSeek',find(s,'S2')),10);assert.equal(actor(s,'DeepSeek').rice,0);});
test('Claude没有实际挡伤不生成新反击',()=>{const{s}=prepared(['Claude']);s.intents=[];act(s,'Claude',find(s,'C1'));finish(s);assert(!actor(s,'Claude').counter);});
test('下线普通回复不能复活',()=>{const{s}=prepared(['GPT','Claude']);hit(s,'GPT',12);const before=clone(s);assert.throws(()=>act(s,'Claude',find(s,'R'),'GPT'),/offline/);assert.deepEqual(s,before);});
test('商店满额与已用服务不扣钱',()=>{const r=run();r.wallet=20;const before=clone(r);assert.throws(()=>service(r,'s','shop','GPT'),/no_heal/);assert.deepEqual(r,before);r.accounts.GPT.token=5;service(r,'s','shop','GPT');const after=clone(r);assert.throws(()=>service(r,'s','shop','GPT'),/used/);assert.deepEqual(r,after);});

const samples=[];
for(const role of data.roles.map(r=>r.id))for(const mode of ['rush','budget']){
 let wins=0,totalToken=0,turns=0;let firstFailure=null;
 for(let seed=1;seed<=100;seed++){
  const r=run([role],seed);let success=true;
  for(const [index,enemy]of ['missing','duplicate','submit'].entries()){
   const s=play(r,`c1-${index}`,[role],enemy,seed*17+index,mode);turns+=s.turn;
   if(s.result!=='win'){success=false;firstFailure??={seed,node:index,enemy,result:s.result,log:s.log};break;}
   settle(r,s);if(index===1&&r.accounts[role].token<12)service(r,'rest1','rest',role);
  }
  if(success){wins++;totalToken+=r.accounts[role].token;}
 }
 samples.push({role,policy:mode,seeds:100,wins,winRate:wins/100,meanFinalTokenOnWins:wins?+(totalToken/wins).toFixed(2):null,meanTurnsPerAttempt:+(turns/100).toFixed(2),firstFailure});
}
const routes=[];
for(const pair of [['GPT','Claude'],['GPT','DeepSeek'],['Claude','DeepSeek']]){
 let wins=0,hiddenWins=0;let example=null;
 for(let seed=1;seed<=40;seed++){
  const r=run(pair,seed);for(const code of data.roles.find(x=>x.id===pair[1]).cards)r.deck.push({id:`recruit-${code}`,code,upgraded:false});
  // A deliberately injured entry, not a simulated full first chapter.
  r.accounts[pair[0]].token=8;r.accounts[pair[1]].token=10;
  let success=true;
  for(const [i,e]of ['conflict','overflow','recipient'].entries()){
   const s=play(r,`c2-${i}`,pair,e,seed*13+i,'budget');if(s.result!=='win'){success=false;break;}settle(r,s,{task:i===2?'invite':null,terminal:i===2});
   if(i===1){const low=pair.toSorted((a,b)=>r.accounts[a].token-r.accounts[b].token)[0];if(r.accounts[low].token<12)service(r,'rest2','rest',low);}
  }
  if(success){wins++;const entry=Object.fromEntries(pair.map(id=>[id,r.accounts[id].token]));r.difficulty=2;const available=pair.filter(id=>r.accounts[id].token>0);const h=play(r,'hidden',available,'hidden',seed*23,'budget');if(h.result==='win')hiddenWins++;example??={seed,entry,hiddenResult:h.result,log:h.log};}
 }
 routes.push({pair,seeds:40,chapterTwoWins:wins,hiddenWins,hiddenAttempts:wins,example});
}
const fullChallenge=[];
for(const pair of [['GPT','Claude'],['GPT','DeepSeek'],['Claude','DeepSeek']]){
 let reachedSecond=0,regularWins=0,hiddenWins=0;const failures={};let example=null;
 for(let seed=1;seed<=40;seed++){
  const r=run([pair[0]],seed);r.stage=seed%2?'student':'employee';r.profile.regularClear=true;r.profile.maxDifficulty=2;setDifficulty(r,2);
  let survived=true;
  const last=finalBoss(r.stage,(seed*0.61803398875)%1,true);
  for(const [i,e]of ['missing','duplicate','submit','conflict','overflow',last,'hidden'].entries()){
    const ids=Object.keys(r.accounts).filter(id=>r.accounts[id].token>0);const s=play(r,`full-${i}`,ids,e,seed*31+i,'budget');
    if(s.result!=='win'){failures[e]=(failures[e]||0)+1;survived=false;break;}
    settle(r,s,{task:i===2?'report':i===5?'invite':null,terminal:i===5});
    if(i===1||i===4){const low=Object.keys(r.accounts).toSorted((a,b)=>r.accounts[a].token-r.accounts[b].token)[0];if(r.accounts[low].token<12)service(r,`rest-${i}`,'rest',low);}
    if(i===2){reachedSecond++;recruit(r,pair[1],'recruit');}
    if(i===5){regularWins++;example??={seed,stage:r.stage,finalBoss:e,hiddenEntry:clone(r.accounts)};}
  }
  if(survived)hiddenWins++;
 }
 fullChallenge.push({pair,seeds:40,difficulty:2,reachedSecond,regularWins,hiddenWins,failures,example});
}
const report={version:data.version,deterministicTests:tests.length,tests,scope:'离线数据规则模型；600个单人首章策略样本、120个受损双人第二章样本、120个全程D2两章加隐藏样本。启发式策略不代表真人或最优策略。JSON往返非真实落盘。',soloSamples:samples,pairSamples:routes,fullChallenge};
fs.writeFileSync(path.join(root,'docs/综合验算结果.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({tests:tests.length,solo:samples.map(({firstFailure,...x})=>x),pairs:routes.map(({example,...x})=>x),fullChallenge},null,2));
