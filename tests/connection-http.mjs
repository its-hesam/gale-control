import assert from 'node:assert/strict';
const origin='http://192.168.10.1';let sequence=0;
async function raw(sid,obj,method,args={}){const response=await fetch(origin+'/ubus',{method:'POST',signal:AbortSignal.timeout(15000),headers:{'Content-Type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++sequence,method:'call',params:[sid,obj,method,args]})});return response.json()}
async function call(sid,obj,method,args={}){const b=await raw(sid,obj,method,args);assert.equal(b.result?.[0],0);assert(!b.result[1]?.error,b.result[1]?.error);return b.result[1]}
const zero='0'.repeat(32);
for(const method of ['status','connect','disconnect','test_udp'])assert.notEqual((await raw(zero,'gale-connection',method)).result?.[0],0);
const sid=(await call(zero,'session','login',{username:'root',password:'',timeout:180})).ubus_rpc_session;
let started=false;
try{
 const before=await call(sid,'gale-connection','status');assert.equal(before.active,null,'test requires no active user connection');
 const catalog=await call(sid,'gale-profiles','list'),candidate=catalog.profiles.find(p=>p.protocol==='vmess'&&p.native_status==='passed');assert(candidate);
 await call(sid,'gale-connection','connect',{id:candidate.id,auto_connect:false});
 started=true;
 let verified=false;
 for(let i=0;i<45;i++){
  await new Promise(r=>setTimeout(r,2000));const status=await call(sid,'gale-connection','status');
  if(status.operation?.state==='failed')throw Error(status.operation.error);
  if(status.running&&status.health?.ok){assert.equal(status.network_routing_active,false);assert.equal(status.active.profile_id,candidate.id);verified=true;console.log(JSON.stringify({persistent_proxy_https:true,core:status.active.core,latency_ms:Math.round(status.health.latency_ms),network_routing_active:false}));break}
 }
 assert(verified,'persistent proxy HTTPS was not verified');
 await call(sid,'gale-connection','test_udp',{kind:process.argv.includes('--ntp')?'ntp':'dns'});let udp=false;
 for(let i=0;i<20;i++){await new Promise(r=>setTimeout(r,1000));let s=await call(sid,'gale-connection','status');if(s.udp?.state!=='queued'){assert(s.udp?.ok,s.udp?.error||'UDP test failed');udp=true;break}}
 assert(udp,'UDP API did not finish');console.log('PASS real UDP '+(process.argv.includes('--ntp')?'NTP':'DNS')+' through active VPN and asynchronous UDP API');
 const security=await raw(sid,'gale-profiles','set_security',{allow_insecure:true});assert.equal(security.result?.[1]?.error,'DISCONNECT_BEFORE_SECURITY_CHANGE');
 const core=await raw(sid,'gale-cores','activate',{id:'sing-box',version:'1.13.12'});assert.equal(core.result?.[1]?.error,'DISCONNECT_BEFORE_CORE_CHANGE');
}finally{
 if(started){await call(sid,'gale-connection','disconnect');const after=await call(sid,'gale-connection','status');assert.equal(after.active,null);assert.equal(after.running,false);assert.equal(after.auto_connect,false);}
 await call(sid,'session','destroy');
}
console.log('PASS persistent local proxy, real HTTPS, mutation guards, stop and anonymous ACL');
