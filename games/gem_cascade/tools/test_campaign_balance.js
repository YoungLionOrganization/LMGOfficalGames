#!/usr/bin/env node
const fs=require('fs'), vm=require('vm'), path=require('path');
const root=path.resolve(__dirname,'..');
const ctx={console}; vm.createContext(ctx);
vm.runInContext(fs.readFileSync(path.join(root,'js','BoardLogic.js'),'utf8'),ctx,{filename:'BoardLogic.js'});
vm.runInContext(fs.readFileSync(path.join(root,'js','LevelLogic.js'),'utf8'),ctx,{filename:'LevelLogic.js'});
const B=ctx;
function assert(c,m){if(!c)throw new Error(m)}
function lcg(seed=1){let x=seed>>>0;return(lo,hi)=>{x=(Math.imul(1664525,x)+1013904223)>>>0;return lo+(x%(hi-lo+1));}}
function seedIce(layers,rnd){const ice=Array(64).fill(0);let placed=0,guard=0;while(placed<layers&&guard++<1200){const p=rnd(8,55);if(ice[p]<2){ice[p]++;placed++;}}return ice;}
function simulate(level,seed){
 const cfg=B.config(level),rnd=lcg(seed);let g=B.generateBoard(8,8,6,rnd);assert(g,'gen');
 let board=g.board,specials=g.specials,ice=seedIce(cfg.iceLayers,rnd),initialIce=cfg.iceLayers,collected=Array(6).fill(0),score=0,bombs=0,bestCascade=0,moves=cfg.moves;
 function iceRemaining(){return ice.reduce((a,v)=>a+v,0)}
 function done(){return score>=cfg.targetScore&&collected[cfg.collectType]>=cfg.collectCount&&(cfg.iceLayers<=0||initialIce-iceRemaining()>=cfg.iceLayers)&&(cfg.bombTarget<=0||bombs>=cfg.bombTarget)&&(cfg.cascadeTarget<=0||bestCascade>=cfg.cascadeTarget)}
 function decision(){return {targetType:cfg.collectType,targetCount:cfg.collectCount,collectedCount:collected[cfg.collectType],targetBombs:cfg.bombTarget,bombsCreated:bombs,targetCascade:cfg.cascadeTarget,bestCascade,movesLeft:moves,ice};}
 while(moves>0&&!done()){
   let action=B.findBestAction(board,specials,8,8,decision());
   if(!action){const sh=B.shufflePairs(board,specials,8,8,rnd);if(!sh)return false;board=sh.board;specials=sh.specials;action=B.findBestAction(board,specials,8,8,decision());if(!action)return false;}
   let plan;
   if(action.type==='activate'){
     plan=B.singleSpecialPlan(board,specials,action.cells[0],8,8);
   }else{
     const a=action.cells[0],b=action.cells[1];
     const combo=B.comboPlan(board,specials,a,b,8,8);
     const sw=B.swapPair(board,specials,a,b);board=sw.board;specials=sw.specials;
     plan=combo||B.buildMatchPlan(board,specials,8,8,a,b);
   }
   moves--; let depth=1,guard=0;
   while(plan&&guard++<40){
     const ns=specials.slice();if(plan.transformed)for(const k of Object.keys(plan.transformed))ns[+k]=+plan.transformed[k];specials=ns;
     const ex=B.expandSpecials(board,specials,plan.clear||{},8,8);const clear=ex.clear,create=plan.create||{};let cleared=0,specialHits=0,created=0,createdNova=0;
     const nb=board.slice(),sp=specials.slice(),ni=ice.slice(),nc=collected.slice();
     for(const k of Object.keys(clear)){const p=+k;if(nb[p]>=0){nc[nb[p]]++;cleared++;}if((sp[p]||0)!==B.NORMAL)specialHits++;nb[p]=-1;sp[p]=B.NORMAL;if(ni[p]>0)ni[p]--;}
     for(const k of Object.keys(create)){const p=+k,q=create[k];nb[p]=+q.type;sp[p]=+q.kind;created++;if(q.kind===B.BOMB)bombs++;if(q.kind===B.NOVA)createdNova++;if(ni[p]>0)ni[p]--;}
     board=nb;specials=sp;ice=ni;collected=nc;
     const mult=depth<=1?1:depth===2?1.25:depth===3?1.5:depth===4?1.75:2;
     const bonuses={line_line:180,bomb_bomb:320,line_bomb:260,prism_normal:240,prism_line:420,prism_bomb:480,prism_nova:560,prism_prism:700,line_nova:420,bomb_nova:520,nova_nova:680,tap_nova:120};
     const comboBonus=plan.label?(bonuses[plan.label]||0):0;
     score+=Math.round(cleared*30*mult+created*160+createdNova*90+specialHits*45+comboBonus);bestCascade=Math.max(bestCascade,depth);
     const fall=B.collapseAndRefill(board,specials,8,8,6,rnd,decision());board=fall.board;specials=fall.specials;
     const runs=B.findRuns(board,8,8);if(!runs.length)break;depth++;plan=B.buildMatchPlan(board,specials,8,8,-1,-1);
   }
 }
 return done();
}
const levels=15,runs=Math.max(1,Number.parseInt(process.env.GEM_CASCADE_BALANCE_RUNS||'24',10)||24);let total=0;const rows=[];
for(let l=1;l<=levels;l++){let wins=0;for(let r=0;r<runs;r++)if(simulate(l,100000*l+r+1))wins++;total+=wins;rows.push({level:l,wins,runs,rate:wins/runs});}
for(const r of rows)console.log(`L${String(r.level).padStart(2,'0')}: ${r.wins}/${r.runs} ${(r.rate*100).toFixed(0)}%`);
const avg=total/(levels*runs);console.log(`Average smart-bot completion: ${(avg*100).toFixed(1)}% across ${levels*runs} simulations`);
assert(avg>=0.65,`campaign feasibility average too low: ${avg}`);
assert(rows.every(r=>r.rate>=0.45),`campaign contains a level below 45% smart feasibility: ${rows.filter(r=>r.rate<0.45).map(r=>r.level).join(',')}`);
console.log('[PASS] Campaign feasibility smoke test');
