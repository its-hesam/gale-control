import assert from 'node:assert/strict';
let sequence=0;async function call(sid,obj,method,args={}){const r=await fetch('http://192.168.10.1/ubus',{method:'POST',signal:AbortSignal.timeout(15000),headers:{'Content-Type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++sequence,method:'call',params:[sid,obj,method,args]})});const b=await r.json();assert.equal(b.result?.[0],0);assert(!b.result[1]?.error,b.result[1]?.error);return b.result[1]}
const sid=(await call('0'.repeat(32),'session','login',{username:'root',password:'',timeout:600})).ubus_rpc_session;let started=false;
try{
 assert(!(await call(sid,'gale-connection','status')).active,'requires idle connection');
 const now=Date.now()/1000,profiles=(await call(sid,'gale-profiles','list')).profiles.filter(p=>p.native_status==='passed'&&p.last_test?.ok&&now-p.last_test.tested_at<900).sort((a,b)=>a.last_test.latency_ms-b.last_test.latency_ms);
 assert(profiles.length>=2,'requires two freshly tested candidates');const fast=profiles[0],slow=profiles.at(-1);
 await call(sid,'gale-connection','connect',{id:slow.id,mode:'best',pool:[slow.id,fast.id].join(','),auto_connect:false});started=true;
 let switched=false,last='';
 for(let i=0;i<150;i++){await new Promise(r=>setTimeout(r,2000));const s=await call(sid,'gale-connection','status');const phase=s.active?.profile_id===fast.id?'new_candidate':'initial_candidate';if(phase!==last){console.log(JSON.stringify({best_mode_phase:phase}));last=phase}if(s.operation?.state==='failed')throw Error(s.operation.error);if(phase==='new_candidate'&&s.running&&s.health?.ok){switched=true;console.log(JSON.stringify({automatic_best_switch_https:true,latency_ms:Math.round(s.health.latency_ms),network_routing_active:false}));break}}
 if(!switched)console.log(JSON.stringify({automatic_best_switch_https:false,observation:'No verified switch within the observation window; live latency thresholds may not have been met.'}));
}finally{if(started)await call(sid,'gale-connection','disconnect');await call(sid,'session','destroy')}
