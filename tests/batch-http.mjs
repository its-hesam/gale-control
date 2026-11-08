import assert from 'node:assert/strict';
let serial=0;const origin='http://192.168.10.1';
async function call(sid,obj,method,args={}){const response=await fetch(origin+'/ubus',{method:'POST',signal:AbortSignal.timeout(5000),headers:{'Content-Type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++serial,method:'call',params:[sid,obj,method,args]})});const body=await response.json();assert.equal(body.result?.[0],0);assert(!body.result[1]?.error,body.result[1]?.error);return body.result[1]}
const auth=await call('0'.repeat(32),'session','login',{username:'root',password:'',timeout:120}),sid=auth.ubus_rpc_session;
try{
 const catalog=await call(sid,'gale-profiles','list');assert.equal(catalog.security.allow_insecure,true);
 const p=catalog.profiles.find(p=>p.protocol==='vmess'&&p.native_status==='passed'&&p.last_test?.ok);assert(p,'successful VMess candidate required');
 await call(sid,'gale-jobs','start',{kind:'benchmark',id:p.id,limit:1});
 let finished=false,maxReadMs=0;
 for(let i=0;i<30;i++){
  const start=performance.now();await call(sid,'gale-status','status');const job=(await call(sid,'gale-jobs','status')).job;
  maxReadMs=Math.max(maxReadMs,performance.now()-start);
  if(job.state==='complete'){assert.equal(job.total,1);assert.equal(job.processed,1);finished=true;console.log(JSON.stringify({single_probe_passed:job.passed===1,max_telemetry_and_job_read_ms:Math.round(maxReadMs)}));break}
  await new Promise(resolve=>setTimeout(resolve,500));
 }
 assert(finished,'background job did not finish');assert(maxReadMs<5000,'background probe blocked RPC reads');
}finally{await call(sid,'session','destroy')}
