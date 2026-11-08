import {test} from 'node:test';
import assert from 'node:assert/strict';
import {firmwareStatus,ensureFirmware} from '../scripts/firmware-upgrade.mjs';
const board=(version='24.10.4')=>({model:'Fixture router',board_name:'fixture,router',release:{distribution:'OpenWrt',target:'ipq40xx/generic',version}});
function fixture({fail='',after=board('25.12.6')}={}){
 const calls=[];let closed=0,saved=false,prompts=0;
 const transport={exec:async(command,input)=>{calls.push(input||command);if(command==='ubus call system board')return JSON.stringify(board());if(input?.includes(fail)&&fail)throw Error('controlled fixture failure');if(input?.includes('base64 /tmp'))return Buffer.from([31,139,8,0]).toString('base64');return 'fixture OK';},close:async()=>{closed++;}};
 const next={exec:async()=>JSON.stringify(after),close:async()=>{closed++;}};
 const options={transport,reconnect:async()=>next,confirm:async()=>{prompts++;return true;},fetcher:async()=>({ok:true,json:async()=>({latest:['25.12.6'],branches:{'25.12':{enabled:true,targets:{'ipq40xx/generic':'arm_cortex-a7_neon-vfpv4'}}}})}),saveBackup:async()=>{saved=true;},sleep:async()=>{},attempts:2};
 return {calls,options,next,stats:()=>({closed,saved,prompts})};
}
test('firmware classification rejects snapshots, forks, older migrations and downgrades',()=>{
 assert.equal(firmwareStatus(board('25.12.6')),'supported');assert.equal(firmwareStatus(board()),'upgrade');
 for(const v of ['23.05.5','26.01.0','25.12.0-rc1','SNAPSHOT'])assert.throws(()=>firmwareStatus(board(v)),/Unsupported/);
 assert.throws(()=>firmwareStatus({...board(),release:{...board().release,distribution:'ImmortalWrt'}}),/Official OpenWrt/);
});
test('read-only and batch runs never prompt or modify incompatible firmware',async()=>{
 for(const flag of ['check','batch']){const f=fixture();await assert.rejects(ensureFirmware({...f.options,[flag]:true}),/not performed/);assert.deepEqual(f.calls,['ubus call system board']);assert.equal(f.stats().prompts,0);}
});
test('declining upgrade never installs tools, backs up or flashes',async()=>{
 const f=fixture();await assert.rejects(ensureFirmware({...f.options,confirm:async()=>false}),/cancelled/);assert(!f.calls.some(c=>/sysupgrade -b|owut download|nohup/.test(c)));assert.equal(f.stats().saved,false);
});
test('firmware path saves backup before validating and flashing, then verifies returned device',async()=>{
 const f=fixture();assert.equal(await ensureFirmware(f.options),f.next);assert(f.stats().saved);assert.equal(f.stats().prompts,1);
 const backup=f.calls.findIndex(c=>c.includes('sysupgrade -b')),validate=f.calls.findIndex(c=>c.includes('owut download')),flash=f.calls.findIndex(c=>c.includes('nohup'));
 assert(backup<validate&&validate<flash);assert(f.calls[validate].includes('sysupgrade -T'));assert(!f.calls.some(c=>/sysupgrade -[Fn]|--force/.test(c)));
});
test('failed image validation and failed backup both stop before flash',async()=>{
 for(const fail of ['owut download','base64 /tmp']){const f=fixture({fail});await assert.rejects(ensureFirmware(f.options),/controlled/);assert(!f.calls.some(c=>c.includes('nohup')));}
 const f=fixture();await assert.rejects(ensureFirmware({...f.options,saveBackup:async()=>{throw Error('disk full');}}),/disk full/);assert(!f.calls.some(c=>c.includes('owut download')));
});
test('wrong post-reboot device or firmware never resumes installation',async()=>{
 for(const after of [board(),{...board('25.12.6'),board_name:'other'}]){const f=fixture({after});await assert.rejects(ensureFirmware(f.options),/did not return/);}
});
test('missing official target stops before consent or any writes',async()=>{
 const f=fixture();await assert.rejects(ensureFirmware({...f.options,fetcher:async()=>({ok:true,json:async()=>({latest:['25.12.6'],branches:{}})})}),/No supported official/);assert.equal(f.stats().prompts,0);assert(!f.calls.some(c=>c.includes('sysupgrade -b')));
});
test('changed SSH identity after reboot aborts reconnection without bypass',async()=>{
 const f=fixture();await assert.rejects(ensureFirmware({...f.options,reconnect:async()=>{throw Error('SSH host key is changed');}}),/host key is changed/);assert.equal(f.stats().closed,1);
});
