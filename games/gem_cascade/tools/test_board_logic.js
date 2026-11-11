#!/usr/bin/env node
const fs = require('fs');
const vm = require('vm');
const path = require('path');
const root = path.resolve(__dirname, '..');
const code = fs.readFileSync(path.join(root, 'js', 'BoardLogic.js'), 'utf8');
const B = { console };
vm.createContext(B);
vm.runInContext(code, B, { filename: 'BoardLogic.js' });

function assert(cond, msg) { if (!cond) throw new Error(msg); }
function empty(cols, rows) { return Array(cols * rows).fill(-1); }
function normal(n) { return Array(n).fill(B.NORMAL); }
function keys(o) { return Object.keys(o).map(Number); }
function has(o, i) { return Object.prototype.hasOwnProperty.call(o, String(i)); }
const STRESS_RUNS = Math.max(50, Number(process.env.GEM_CASCADE_STRESS_RUNS || 300));

function testSpecialCreation() {
  let b = empty(6,6), s = normal(36);
  [6,7,8,9].forEach(i => b[i]=1);
  let p = B.buildMatchPlan(b,s,6,6,8,9);
  assert(Object.values(p.create)[0].kind === B.ROW, 'horizontal 4 must create ROW');

  b = empty(6,6); s = normal(36); [1,7,13,19].forEach(i=>b[i]=2);
  p = B.buildMatchPlan(b,s,6,6,13,19);
  assert(Object.values(p.create)[0].kind === B.COLUMN, 'vertical 4 must create COLUMN');

  b = empty(6,6); s = normal(36); [12,13,14,15,16].forEach(i=>b[i]=3);
  p = B.buildMatchPlan(b,s,6,6,15,16);
  assert(Object.values(p.create)[0].kind === B.PRISM, '5-match must create PRISM');

  b = empty(6,6); s = normal(36); [18,19,20,21,22,23].forEach(i=>b[i]=4);
  p = B.buildMatchPlan(b,s,6,6,22,23);
  assert(Object.values(p.create)[0].kind === B.NOVA, '6-match must create NOVA');

  b = empty(5,5); s = normal(25); [11,12,13,7,17].forEach(i=>b[i]=4);
  p = B.buildMatchPlan(b,s,5,5,12,13);
  assert(Object.values(p.create)[0].kind === B.BOMB, 'T-match must create BOMB');

  b = empty(5,5); s = normal(25); [5,6,7,8].forEach(i=>b[i]=1); s[8]=B.BOMB;
  p = B.buildMatchPlan(b,s,5,5,7,8);
  const anchor = Number(Object.keys(p.create)[0]);
  assert(anchor !== 8, 'new special must choose a normal anchor');
  assert(has(p.clear,8), 'existing special must remain in clear set so it activates');
}

function testLegalityIsolation() {
  const b = empty(5,5), s = normal(25);
  b[0]=1; b[1]=1; b[2]=1;
  b[18]=2; b[19]=3;
  assert(!B.isLegalSwap(b,s,18,19,5,5), 'unrelated existing match must not legalize swap');

  const c = empty(3,3), cs = normal(9);
  c[0]=0; c[1]=1; c[2]=0; c[4]=0;
  assert(B.isLegalSwap(c,cs,1,4,3,3), 'swap that creates a local run must be legal');
}

function testCombosAndExpansion() {
  const cols=8, rows=8, n=64, board=Array(n).fill(0);
  const pairs = [
    [B.ROW,B.COLUMN,'line_line'], [B.BOMB,B.BOMB,'bomb_bomb'],
    [B.ROW,B.BOMB,'line_bomb'], [B.PRISM,B.NORMAL,'prism_normal'],
    [B.PRISM,B.ROW,'prism_line'], [B.PRISM,B.BOMB,'prism_bomb'],
    [B.PRISM,B.NOVA,'prism_nova'], [B.ROW,B.NOVA,'line_nova'],
    [B.BOMB,B.NOVA,'bomb_nova'], [B.NOVA,B.NOVA,'nova_nova'],
    [B.PRISM,B.PRISM,'prism_prism']
  ];
  for (const [sa,sb,label] of pairs) {
    const sp=normal(n); sp[27]=sa; sp[28]=sb; board[28]=2;
    const p=B.comboPlan(board,sp,27,28,cols,rows);
    assert(p && p.label===label, `combo ${label} missing`);
    assert(keys(p.clear).length>=2, `combo ${label} clear set too small`);
  }
  let sp=normal(n); sp[27]=B.BOMB;
  let expanded=B.expandSpecials(board,sp,{27:true},cols,rows);
  assert(keys(expanded.clear).length===9, 'bomb must clear 3x3 away from edges');
  sp[27]=B.ROW;
  assert(keys(B.expandSpecials(board,sp,{27:true},cols,rows).clear).length===8, 'ROW must clear row');
  sp[27]=B.COLUMN;
  assert(keys(B.expandSpecials(board,sp,{27:true},cols,rows).clear).length===8, 'COLUMN must clear column');
  sp[27]=B.NOVA;
  assert(keys(B.expandSpecials(board,sp,{27:true},cols,rows).clear).length > 20, 'NOVA must clear a large starburst area');
}

function testManualSpecialActivation() {
  const cols=8, rows=8, n=64;
  const board = Array.from({length:n}, (_,i)=>i%6);
  let sp=normal(n); sp[27]=B.ROW;
  assert(B.singleSpecialPlan(board,sp,27,cols,rows).label === 'tap_line_row', 'manual row plan missing');
  sp=normal(n); sp[27]=B.COLUMN;
  assert(B.singleSpecialPlan(board,sp,27,cols,rows).label === 'tap_line_column', 'manual column plan missing');
  sp=normal(n); sp[27]=B.BOMB;
  assert(keys(B.singleSpecialPlan(board,sp,27,cols,rows).clear).length >= 20, 'manual bomb should clear 5x5 near center');
  sp=normal(n); sp[27]=B.PRISM;
  assert(keys(B.singleSpecialPlan(board,sp,27,cols,rows).clear).length >= 8, 'manual prism should clear a board color');
  sp=normal(n); sp[27]=B.NOVA;
  assert(keys(B.singleSpecialPlan(board,sp,27,cols,rows).clear).length > 20, 'manual nova should clear a large starburst area');
}

function lcg(seed=1) { let x=seed>>>0; return (lo,hi)=>{ x=(1664525*x+1013904223)>>>0; return lo + (x % (hi-lo+1)); }; }
function testGenerationShuffleAndCascade() {
  for (let t=0;t<STRESS_RUNS;t++) {
    const rnd=lcg(t+1);
    const g=B.generateBoard(8,8,6,rnd);
    assert(g, 'generation failed');
    assert(B.findRuns(g.board,8,8).length===0, 'initial match found');
    assert(B.findPossibleMove(g.board,g.specials,8,8).length===2, 'no legal move');
    g.specials[3]=B.ROW; g.specials[17]=B.BOMB; g.specials[42]=B.PRISM; g.specials[55]=B.NOVA;
    const sh=B.shufflePairs(g.board,g.specials,8,8,rnd);
    assert(sh, 'shuffle failed');
    assert(B.findRuns(sh.board,8,8).length===0, 'shuffle created initial match');
    assert(B.findPossibleMove(sh.board,sh.specials,8,8).length===2, 'shuffle has no legal move');
    const kinds=sh.specials.filter(x=>x!==B.NORMAL).sort((a,b)=>a-b).join(',');
    assert(kinds===[B.ROW,B.BOMB,B.PRISM,B.NOVA].sort((a,b)=>a-b).join(','), 'shuffle lost special kinds');

    let board2=sh.board.slice(), specials=sh.specials.slice();
    const mv=B.findPossibleMove(board2,specials,8,8); const sw=B.swapPair(board2,specials,mv[0],mv[1]);
    board2=sw.board; specials=sw.specials;
    let guard=0;
    while (guard++<64) {
      const plan=B.buildMatchPlan(board2,specials,8,8,-1,-1);
      if (plan.runs.length===0) break;
      const clear=B.expandSpecials(board2,specials,plan.clear,8,8).clear;
      for (const k of keys(clear)) { board2[k]=-1; specials[k]=B.NORMAL; }
      for (const k of Object.keys(plan.create)) { const q=plan.create[k]; board2[k]=q.type; specials[k]=q.kind; }
      const fall=B.collapseAndRefill(board2,specials,8,8,6,rnd); board2=fall.board; specials=fall.specials;
      assert(board2.length===64 && specials.length===64, 'collapse changed board size');
      assert(board2.every(v=>v>=0 && v<6), 'refill left invalid gem');
    }
    assert(guard<64, 'cascade safety bound exceeded');
  }
}

function testPathologicalRngFallback() {
  const constant = (lo, hi) => lo;
  const g = B.generateBoard(8,8,6,constant);
  assert(g, 'deterministic fallback must recover from constant host RNG');
  assert(B.findRuns(g.board,8,8).length===0, 'fallback board contains an initial match');
  assert(B.findPossibleMove(g.board,g.specials,8,8).length===2, 'fallback board has no legal move');
  g.specials[1]=B.ROW; g.specials[11]=B.BOMB; g.specials[31]=B.PRISM; g.specials[41]=B.NOVA;
  const sh=B.shufflePairs(g.board,g.specials,8,8,constant);
  assert(sh, 'shuffle fallback must recover from constant host RNG');
  assert(B.findRuns(sh.board,8,8).length===0, 'shuffle fallback contains an initial match');
  assert(B.findPossibleMove(sh.board,sh.specials,8,8).length===2, 'shuffle fallback has no legal move');
  const kinds=sh.specials.filter(x=>x!==B.NORMAL).sort((a,b)=>a-b).join(',');
  assert(kinds===[B.ROW,B.BOMB,B.PRISM,B.NOVA].sort((a,b)=>a-b).join(','), 'constant-RNG shuffle fallback lost specials');
}

testSpecialCreation();
testLegalityIsolation();
testCombosAndExpansion();
testManualSpecialActivation();
testGenerationShuffleAndCascade();
testPathologicalRngFallback();
console.log('[PASS] BoardLogic regression suite: specials, manual activation, combos, legality isolation, pathological-RNG fallback, ' + STRESS_RUNS + ' generation/shuffle/cascade stress iterations');
