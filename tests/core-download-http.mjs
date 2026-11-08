import assert from 'node:assert/strict';
let n=0;async function raw(sid,obj,method,args={}){return (await fetch('http://192.168.10.1/ubus',{method:'POST',signal:AbortSignal.timeout(10000),headers:{'Content-Type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++n,method:'call',params:[sid,obj,method,args]})})).json()}
async function call(sid,method,args={}){const b=await raw(sid,'gale-cores',method,args);assert.equal(b.result?.[0],0);assert(!b.result[1]?.error,b.result[1]?.error);return b.result[1]}
const zero='0'.repeat(32);for(const method of ['status','stage','activate','rollback'])assert.notEqual((await raw(zero,'gale-cores',method,{id:'sing-box',version:'1.13.11'})).result?.[0],0);
const login=await raw(zero,'session','login',{username:'root',password:'',timeout:600}),sid=login.result[1].ubus_rpc_session;
try{
 const before=await call(sid,'status'),current=before.cores.find(c=>c.id==='sing-box').current;
 if(!before.cores.find(c=>c.id==='sing-box').releases.some(r=>r.version==='1.13.11')){
  await call(sid,'stage',{id:'sing-box',version:'1.13.11',allow_prerelease:false});let finished=false,last='';
  for(let i=0;i<100;i++){await new Promise(r=>setTimeout(r,3000));const s=await call(sid,'status');if(s.download.state!==last){console.log('Core download:',s.download.state);last=s.download.state}if(s.download.state==='failed')throw Error(s.download.error);if(s.download.state==='staged'){finished=true;break}}
  assert(finished,'download job did not finish');
 }
 const after=await call(sid,'status'),core=after.cores.find(c=>c.id==='sing-box');assert.equal(core.current,current);const release=core.releases.find(r=>r.version==='1.13.11');assert.equal(release.verification,'official_github_asset_sha256');assert.match(release.binary_sha256,/^[0-9a-f]{64}$/);
 console.log('PASS router-side official download, archive digest, native staging, anonymous ACL and unchanged active core');
}finally{await raw(sid,'session','destroy')}
