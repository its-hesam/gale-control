import assert from 'node:assert/strict';
const origin='http://192.168.10.1';let id=0;
async function call(sid,obj,method,args={}){const r=await fetch(origin+'/ubus',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++id,method:'call',params:[sid,obj,method,args]})});return r.json()}
const zero='0'.repeat(32);
const anon=await call(zero,'gale-status','status');assert.notEqual(anon.result?.[0],0);console.log('PASS anonymous telemetry denied');
for(const method of ['core_inventory','core_selftest']){const r=await call(zero,'gale-status',method);assert.notEqual(r.result?.[0],0)}console.log('PASS anonymous inventory and native checks denied');
for(const [object,method,args] of [['gale-jobs','status',{}],['gale-jobs','start',{kind:'benchmark'}],['gale-profiles','set_security',{allow_insecure:true}],['gale-profiles','list',{}],['gale-profiles','import',{content:'invalid'}],['gale-profiles','benchmark',{id:'invalid'}],['gale-sources','list',{}],['gale-sources','add',{url:'https://example.com/',name:'unauthorized'}],['gale-sources','set_interval',{id:'invalid',seconds:3600}]]){const result=await call(zero,object,method,args);assert.notEqual(result.result?.[0],0)}console.log('PASS anonymous profile/source reads and writes denied');
const auth=await call(zero,'session','login',{username:'root',password:'',timeout:60});assert.equal(auth.result[0],0);const sid=auth.result[1].ubus_rpc_session;
try{
 const result=await call(sid,'gale-status','status');assert.equal(result.result[0],0);const data=result.result[1];assert.equal(data.schema_version,1);assert.equal(data.board.model,'Google WiFi (Gale)');assert(data.system.memory.total>0);assert(data.system.cpu_ticks.length===8);assert(data.services.some(s=>s.name==='dropbear'&&s.instances.some(i=>i.running)));assert(!JSON.stringify(data).match(/private_key|password|command|token|uuid/i));
 console.log('PASS authenticated telemetry schema, live memory, CPU, SSH service and output allowlist');
 for(const object of ['gale-profiles','gale-sources']){const r=await call(sid,object,'list');assert.equal(r.result[0],0);assert.equal(r.result[1].schema_version,1)}console.log('PASS authenticated profile/source API schema');
 const inventory=await call(sid,'gale-status','core_inventory');assert.equal(inventory.result[0],0);assert.equal(inventory.result[1].architecture,'arm_cortex-a7_neon-vfpv4');assert.equal(inventory.result[1].cores.length,5);assert(inventory.result[1].cores.every(c=>c.version_ok&&c.verification==='not_tested'));assert.equal(inventory.result[1].legacy_boot_disabled,true);console.log('PASS real core versions and migration state');
 const checks=await call(sid,'gale-status','core_selftest');assert.equal(checks.result[0],0);assert.equal(checks.result[1].results.length,3);assert(checks.result[1].results.every(c=>c.passed&&c.handshake_tested===false));console.log('PASS three native offline checks, explicitly no handshake claim');
 const unsupported=await call(sid,'gale-status','exec',{command:'echo no'});assert.notEqual(unsupported.result?.[0],0);console.log('PASS unsupported method denied');
 const page=await fetch(origin+'/gale/');assert(page.ok);assert((await page.text()).includes('Gale'));console.log('PASS Foundation HTTP 200');
 const luci=await fetch(origin+'/cgi-bin/luci/');const html=await luci.text();assert(luci.ok||(luci.status===403&&html.includes('OpenWrt')));console.log('PASS LuCI responds (HTTP '+luci.status+'; unauthenticated login returns 403, browser login verified separately)');
}finally{await call(sid,'session','destroy')}
const expired=await call(sid,'gale-status','status');assert.notEqual(expired.result?.[0],0);console.log('PASS destroyed session denied');
