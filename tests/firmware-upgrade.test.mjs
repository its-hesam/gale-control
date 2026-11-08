import {test} from 'node:test';
import assert from 'node:assert/strict';
import {firmwareStatus,ensureFirmware,prepareFirmware,missingFirmwarePackages} from '../scripts/firmware-upgrade.mjs';
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
 assert(backup<validate&&validate<flash);assert(f.calls[validate].includes('sysupgrade -T'));assert(f.calls.findIndex(c=>c.includes('owut check --verbose'))<validate);assert(f.calls[validate].includes('cat "$log" >&2')); assert(!f.calls.some(c=>/sysupgrade -[Fn]|--force/.test(c)));
});
test('failed image validation and failed backup both stop before flash',async()=>{
 for(const fail of ['owut check','owut download','base64 /tmp']){const f=fixture({fail});await assert.rejects(ensureFirmware(f.options),/controlled/);assert(!f.calls.some(c=>c.includes('nohup')));}
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
const missing='  chinadns-ng 2025-r1 missing to-version\n  luci-app-passwall2 25-r1 missing to-version\n2 packages missing in target version, cannot upgrade\nERROR: Checks reveal errors, do not upgrade';
test('missing package parser requires complete exact summary and rejects injection',()=>{
 assert.deepEqual(missingFirmwarePackages(missing),['chinadns-ng','luci-app-passwall2']);assert.deepEqual(missingFirmwarePackages(missing.replace('2 packages','3 packages')),[]);assert.deepEqual(missingFirmwarePackages(missing.replace('chinadns-ng','bad;command')),[]);
});
test('approved legacy omissions are used for both repeated check and download without uninstalling',async()=>{
 const calls=[];let checks=0,prompts=0;
 await prepareFirmware({target:'25.12.6',confirm:async message=>{prompts++;assert(message.includes('Passwall2'));return true;},transport:{exec:async(_,script)=>{calls.push(script);if(script.includes('owut check')&&++checks===1)throw Error(missing);return 'OK';}}});
 assert.equal(prompts,1);assert.equal(checks,2);
 const check=calls.find(s=>s.includes('owut check')&&s.includes('--remove')),download=calls.find(s=>s.includes('owut download'));
 assert(check.includes('--remove chinadns-ng,luci-app-passwall2'));assert(download.includes('--remove chinadns-ng,luci-app-passwall2'));assert(!calls.some(s=>/opkg remove|--force|sysupgrade -F/.test(s)));
});
test('declined omissions or unknown missing packages stop before firmware download',async()=>{
 for(const output of [missing,missing.replace('chinadns-ng','netifd')]){let downloaded=false;await assert.rejects(prepareFirmware({target:'25.12.6',confirm:async()=>false,transport:{exec:async(_,s)=>{if(s.includes('owut check'))throw Error(output);if(s.includes('owut download'))downloaded=true;return '';}}}),/cancelled|manual review/);assert(!downloaded);}
});
test('transient checks retry twice; persistent errors and failed approved rechecks never download',async()=>{
 for(const permanent of [false,true]){let checks=0,downloaded=false,waits=0;const options={target:'25.12.6',sleep:async()=>{waits++;},transport:{exec:async(_,s)=>{if(s.includes('owut check')&&(++checks<3||permanent))throw Error('ERROR: Failed to connect');if(s.includes('owut download'))downloaded=true;return '';}}};if(permanent)await assert.rejects(prepareFirmware(options),/Failed to connect/);else await prepareFirmware(options);assert.equal(checks,3);assert.equal(waits,2);assert.equal(downloaded,!permanent);}
 let checks=0;await assert.rejects(prepareFirmware({target:'25.12.6',confirm:async()=>true,transport:{exec:async(_,s)=>{if(s.includes('owut check')){checks++;throw Error(missing);}assert(!s.includes('owut download'));return '';}}}),/Checks reveal errors/);assert.equal(checks,2);
});
