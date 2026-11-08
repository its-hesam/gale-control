import {test} from 'node:test';import assert from 'node:assert/strict';
import {runStage} from '../scripts/command-progress.mjs';
import {execProcess} from '../scripts/ssh-transport.mjs';
test('process transport streams both outputs before exit and keeps return value',async()=>{
 let received,finished=false;const first=new Promise(r=>received=r),err=[];
 const pending=execProcess(process.execPath,['-e',"process.stdout.write('first');setTimeout(()=>{process.stderr.write('note');process.stdout.write('last');},150)"],'',5000,{onStdout:()=>received(),onStderr:c=>err.push(c)}).then(r=>{finished=true;return r;});
 await first;assert(!finished);assert.equal(await pending,'firstlast');assert.equal(Buffer.concat(err).toString(),'note');
});
test('process transport rejects timeout and unsuccessful command',async()=>{
 await assert.rejects(execProcess(process.execPath,['-e','setTimeout(()=>{},10000)'],'',50),/timed out/);
 await assert.rejects(execProcess(process.execPath,['-e',"process.stderr.write('failed fixture');process.exit(7)"],'',5000),/failed fixture/);
});
test('progress emits heartbeat while silent, streams without duplicates and stops timer',async()=>{
 const output=[];let finish,ready;const started=new Promise(r=>ready=r);const transport={exec:async(_command,_script,timeout,hooks)=>{assert.equal(timeout,5000);hooks.onStdout(Buffer.from('real progress\n'));ready();await new Promise(r=>finish=r);return 'real progress\n';}};
 const pending=runStage(transport,{label:'Fixture build',script:'fixture',timeout:5000,heartbeatMs:5,write:c=>output.push(c.toString())});await started;
 await new Promise(r=>setTimeout(r,20));assert(output.some(s=>s.includes('Still waiting')));finish();await pending;
 assert.equal(output.filter(s=>s==='real progress\n').length,1);assert(output.some(s=>s.includes('Completed')));const count=output.length;await new Promise(r=>setTimeout(r,20));assert.equal(output.length,count);
});
test('failed streaming command preserves stdout diagnostics and timeout names stage',async()=>{
 const transport={exec:async(_c,_s,_t,hooks)=>{hooks.onStdout(Buffer.from('missing package details'));throw Error('check failed');}};
 await assert.rejects(runStage(transport,{label:'Check',script:'fixture',write:()=>{}}),/Check.*Failed[\s\S]*missing package details[\s\S]*check failed/);
 await assert.rejects(runStage({exec:async()=>{throw Error('SSH command timed out.');}},{label:'Build',script:'fixture',timeout:500,write:()=>{}}),/Build.*Timed out[\s\S]*remote build may still be running/);
});
