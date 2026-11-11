#!/usr/bin/env node
const fs = require('fs');
const vm = require('vm');
const path = require('path');
const root = path.resolve(__dirname, '..');
const code = fs.readFileSync(path.join(root, 'js', 'LevelLogic.js'), 'utf8');
const L = {};
vm.createContext(L);
vm.runInContext(code, L, { filename: 'LevelLogic.js' });

function assert(cond, msg) { if (!cond) throw new Error(msg); }
function same(a,b) { return JSON.stringify(a) === JSON.stringify(b); }

assert(same(L.boosterRewards(1,1,0), {hammer:1}), 'level 1 first clear reward');
assert(same(L.boosterRewards(2,1,0), {shuffle:1}), 'level 2 first clear reward');
assert(same(L.boosterRewards(3,3,0), {hammer:1,shuffle:1}), 'level 3 first 3-star reward');
assert(same(L.boosterRewards(3,3,1), {shuffle:1}), 'level 3 improved 3-star reward');
assert(same(L.boosterRewards(3,3,3), {}), 'level 3 replay must not farm');
assert(same(L.boosterRewards(4,1,0), {extra:1}), 'level 4 extra-moves rotation reward');
assert(same(L.boosterRewards(5,1,0), {hammer:1,cross:1}), 'level 5 milestone reward');
assert(same(L.boosterRewards(5,3,1), {}), 'level 5 replay/improvement must not duplicate milestone');
assert(same(L.boosterRewards(15,3,0), {hammer:1,shuffle:1,cross:1}), 'level 15 combined milestone/performance reward');

let totals={hammer:0,shuffle:0,cross:0,extra:0};
for(let level=1; level<=30; level++) {
  const r=L.boosterRewards(level,3,0);
  for(const k of Object.keys(r)) totals[k]+=r[k];
  // Replaying a fully-completed level must always return no reward.
  assert(Object.keys(L.boosterRewards(level,3,3)).length===0, `replay farming leak at level ${level}`);
}
assert(totals.cross===6, 'cross milestone economy drift');
assert(totals.extra===6, 'extra-moves base economy drift');
assert(totals.hammer===18, 'hammer economy drift');
assert(totals.shuffle===16, 'shuffle economy drift');
assert(Object.values(totals).reduce((a,b)=>a+b,0)===46, '30-level reward budget drift');
console.log('[PASS] Booster reward economy: non-farmable, milestone-safe, 46 total rewards across 30 perfect first clears', totals);
