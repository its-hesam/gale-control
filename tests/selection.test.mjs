import test from 'node:test';
import assert from 'node:assert/strict';
import {rankCandidates,shouldSwitch} from '../src/domain/selection.mjs';
const profile=(id,latency,age=0)=>({id,enabled:true,native_status:'passed',last_test:{ok:true,latency_ms:latency,tested_at:1000-age}});
test('selection rejects stale, disabled, failed and unverified candidates',()=>{const a=profile('a',100),stale=profile('stale',1,901),failed={...profile('failed',1),native_status:'not_checked'},off={...profile('off',1),enabled:false};assert.deepEqual(rankCandidates([a,stale,failed,off],1000).map(p=>p.id),['a'])});
test('selection does not reward missing measurements or future timestamps',()=>assert.deepEqual(rankCandidates([profile('missing',null),profile('future',1,-1)],1000),[]));
test('fresh measured candidates rank by HTTPS latency',()=>assert.deepEqual(rankCandidates([profile('slow',500),profile('fast',50)],1000).map(p=>p.id),['fast','slow']));
test('manual mode, cooldown and small improvements never switch',()=>{const input={currentId:'a',candidateId:'b',currentScore:10,candidateScore:11,lastSwitchAt:0,now:300,failures:0,mode:'best'};assert.equal(shouldSwitch(input),false);assert.equal(shouldSwitch({...input,mode:'manual',failures:3}),false);assert.equal(shouldSwitch({...input,lastSwitchAt:250,failures:3}),false)});
test('failover requires confirmed failures while best mode requires hysteresis',()=>{const input={currentId:'a',candidateId:'b',currentScore:10,candidateScore:15,lastSwitchAt:0,now:300,failures:0,mode:'failover'};assert.equal(shouldSwitch(input),false);assert.equal(shouldSwitch({...input,failures:3}),true);assert.equal(shouldSwitch({...input,mode:'best'}),true)});
