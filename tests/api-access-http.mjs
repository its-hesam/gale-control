import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
const acl=JSON.parse(readFileSync('router/gale-read.json','utf8'))['gale-read'];
let sequence=0;
async function raw(sid,object,method,args={}){const response=await fetch('http://192.168.10.1/ubus',{method:'POST',signal:AbortSignal.timeout(10000),headers:{'Content-Type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++sequence,method:'call',params:[sid,object,method,args]})});return response.json()}
const zero='0'.repeat(32);let checks=0;
// Local ubus checks the anonymous ACL without permitting an HTTP session override.
const requests=[];for(const section of ['read','write'])for(const [object,methods] of Object.entries(acl[section].ubus))for(const method of methods){if(object!=='session')requests.push({ubus_rpc_session:zero,scope:'ubus',object,function:method});}
const program='import {connect} from "ubus"; let bus=connect(); let results=[]; for(let request in '+JSON.stringify(requests)+')push(results,bus.call("session","access",request)); print(results);';
const local=spawnSync('ssh',['-o','BatchMode=yes','root@192.168.10.1','ucode -'],{input:program,encoding:'utf8',timeout:15000});assert.equal(local.status,0,local.stderr);for(const result of JSON.parse(local.stdout)){assert.equal(result.access,false);checks++;}
for(const [object,method] of [['gale-status','events'],['gale-sources','discover'],['gale-routing','status'],['gale-connection','status']]){assert.notEqual((await raw(zero,object,method)).result?.[0],0);checks++;}
console.log(JSON.stringify({passed:checks,scope:'anonymous_API_authorization_no_mutations'}));
