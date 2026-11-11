#!/usr/bin/env node
const fs = require('fs');
const vm = require('vm');
const path = require('path');
const root = path.resolve(__dirname, '..');
const B = { console };
vm.createContext(B);
vm.runInContext(fs.readFileSync(path.join(root, 'js', 'BoardLogic.js'), 'utf8'), B, { filename: 'BoardLogic.js' });
function assert(c,m){if(!c)throw new Error(m)}
function lcg(seed){let x=seed>>>0;return(lo,hi)=>{x=(1664525*x+1013904223)>>>0;return lo+(x%(hi-lo+1));}}
function avg(a){return a.reduce((x,y)=>x+y,0)/Math.max(1,a.length)}
const runs=Math.max(100,Number(process.env.GEM_CASCADE_GAMER_RUNS||400));
let moveCounts=[], spreads=[], refillSpreads=[], deadAfterRefill=0, objectiveWins=0;
for(let t=1;t<=runs;t++){
  const rnd=lcg(t*17+3), g=B.generateBoard(8,8,6,rnd);
  assert(g,'generation failed');
  assert(B.findRuns(g.board,8,8).length===0,'opening board auto-match');
  const moves=B.enumerateLegalMoves(g.board,g.specials,8,8);
  assert(moves.length>=4,'opening board has too little agency: '+moves.length);
  moveCounts.push(moves.length); spreads.push(B.colorBalance(g.board,6).spread);
  const first=moves[0];
  const target=t%6;
  const ctx={targetType:target,targetCount:12,collectedCount:0,movesLeft:12,ice:Array(64).fill(0),targetBombs:0,bombsCreated:0};
  const best=B.findBestAction(g.board,g.specials,8,8,ctx);
  assert(best && best.cells && best.cells.length>0,'smart hint returned no action');
  if(best.type==='swap'){
    const bestScore=B.moveScore(g.board,g.specials,best.cells[0],best.cells[1],8,8,ctx);
    const firstScore=B.moveScore(g.board,g.specials,first[0],first[1],8,8,ctx);
    assert(bestScore+1e-9>=firstScore,'smart hint scored below first legal move');
    if(bestScore>firstScore+1) objectiveWins++;
  }
  const b=g.board.slice(), s=g.specials.slice();
  for(let k=0;k<10;k++){const p=rnd(0,63);b[p]=-1;s[p]=B.NORMAL;}
  const c=B.collapseAndRefill(b,s,8,8,6,rnd,ctx);
  refillSpreads.push(B.colorBalance(c.board,6).spread);
  if(B.findRuns(c.board,8,8).length===0 && !B.hasPlayableAction(c.board,c.specials,8,8)) deadAfterRefill++;
}
// A lone high-value special should be considered by the hint engine.
{
  const rnd=lcg(999), g=B.generateBoard(8,8,6,rnd); g.specials[27]=B.NOVA;
  const a=B.findBestAction(g.board,g.specials,8,8,{targetType:2,targetCount:10,collectedCount:0,movesLeft:10,ice:Array(64).fill(0)});
  assert(a && (a.type==='activate'||a.type==='swap'),'special-aware hint failed');
}
assert(avg(moveCounts)>=8,'opening agency average too low: '+avg(moveCounts));
assert(avg(spreads)<=7,'opening colour spread too high: '+avg(spreads));
assert(avg(refillSpreads)<=7,'refill colour spread too high: '+avg(refillSpreads));
assert(deadAfterRefill<=Math.max(1,Math.floor(runs*0.01)),'too many dead refills: '+deadAfterRefill);
console.log(`[PASS] Gamer algorithm audit: ${runs} boards, avg legal moves=${avg(moveCounts).toFixed(2)}, avg opening spread=${avg(spreads).toFixed(2)}, avg refill spread=${avg(refillSpreads).toFixed(2)}, dead refills=${deadAfterRefill}, smart-hint improvements=${objectiveWins}`);
