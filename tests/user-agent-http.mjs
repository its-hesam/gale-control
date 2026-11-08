import assert from 'node:assert/strict';
const origin='http://192.168.10.1';let id=0;
async function call(sid,obj,method,args={}){return (await fetch(origin+'/ubus',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++id,method:'call',params:[sid,obj,method,args]})})).json()}
const zero='0'.repeat(32);
const anon=await call(zero,'gale-sources','set_user_agent',{id:'invalid',user_agent:'v2rayN'});assert.notEqual(anon.result?.[0],0);
const auth=await call(zero,'session','login',{username:'root',password:'',timeout:60});assert.equal(auth.result[0],0);const sid=auth.result[1].ubus_rpc_session;
try{
 const before=(await call(sid,'gale-sources','list')).result[1].sources;
 assert(before.length>0,'needs an existing source');
 const first=before[0];
 const denied=await call(sid,'gale-sources','set_user_agent',{id:first.id,user_agent:'bad\r\nX-Injected: value'});
 assert.equal(denied.result[0],0);assert.equal(denied.result[1].error,'BAD_USER_AGENT');
 const after=(await call(sid,'gale-sources','list')).result[1].sources.find(s=>s.id===first.id);
 assert.equal(after.user_agent,first.user_agent);assert.equal(after.profile_count,first.profile_count);
 console.log('PASS HTTP UA ACL, header-injection rejection and preservation of existing source settings');
}finally{await call(sid,'session','destroy')}
