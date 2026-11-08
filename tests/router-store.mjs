import {spawnSync} from 'node:child_process';
import {randomUUID} from 'node:crypto';
import assert from 'node:assert/strict';
const dir='/tmp/gale-test-'+randomUUID();
function ssh(command,input=''){const r=spawnSync('ssh',['-o','BatchMode=yes','root@192.168.10.1',command],{input,encoding:'utf8',maxBuffer:2*1024*1024});if(r.status!==0)throw new Error(r.stderr);return r.stdout}
function call(object,method,args={}){return JSON.parse(ssh(`GALE_TEST_STORE=${dir} /usr/libexec/rpcd/${object} call ${method}`,JSON.stringify(args)))}
const link='vless://00000000-0000-4000-8000-000000000001@203.0.113.1:443?type=xhttp&security=reality&pbk=TESTKEY&sid=abcd#StoreTest';
try{
 assert.equal(call('gale-profiles','list').profiles.length,0);
 const imported=call('gale-profiles','import',{content:link});assert.equal(imported.added,1);assert.equal(imported.errors.length,0);
 assert.equal(call('gale-profiles','import',{content:link.replace('#StoreTest','#Rename')}).duplicates,1);
 const direct='vless://00000000-0000-4000-8000-000000000001@203.0.113.1:443?type=tcp&security=tls&sni=example.com#NativeTest';
 const listed=call('gale-profiles','list');assert.equal(listed.profiles.length,1);assert(!JSON.stringify(listed).includes('TESTKEY'));assert(!JSON.stringify(listed).includes('00000000-0000-4000-8000-000000000001'));
 assert.equal(ssh(`ls -l ${dir}/state.json`).split(/\s+/)[0],'-rw-------');assert.equal(ssh(`ls -ld ${dir}`).split(/\s+/)[0],'drwx------');
 assert.equal(call('gale-profiles','import',{content:'client\nup /tmp/unsafe'}).added,0);assert.equal(call('gale-profiles','list').profiles.length,1);
 assert(call('gale-sources','add',{url:'http://example.com/',name:'Invalid'}).error);
 const added=call('gale-sources','add',{url:'https://192.168.10.1/private?secret=TEST_SECRET',name:'SSRF guard',public_untrusted:true});assert(added.source.id);
 assert.equal(added.source.user_agent,'');
 assert.equal(call('gale-sources','set_user_agent',{id:added.source.id,user_agent:'v2rayN'}).source.user_agent,'v2rayN');
 assert.equal(call('gale-sources','set_user_agent',{id:added.source.id,user_agent:'bad\r\nX-Evil: value'}).error,'BAD_USER_AGENT');
 assert.equal(call('gale-sources','list').sources[0].user_agent,'v2rayN');
 assert.equal(call('gale-sources','due').ids.length,0);
 assert.equal(call('gale-sources','set_interval',{id:added.source.id,seconds:21600}).source.refresh_interval,21600);
 assert.deepEqual(call('gale-sources','due').ids,[added.source.id]);
 assert.equal(call('gale-sources','set_interval',{id:added.source.id,seconds:1}).error,'BAD_REFRESH_INTERVAL');
 assert(!JSON.stringify(call('gale-sources','list')).includes('TEST_SECRET'));
 const refreshed=call('gale-sources','refresh',{id:added.source.id});assert.equal(refreshed.source.last_error,'SOURCE_PRIVATE_ADDRESS_BLOCKED');assert.equal(call('gale-profiles','list').profiles.length,1);
 assert.equal(refreshed.source.last_user_agent,'v2rayN');
 assert.equal(call('gale-sources','due').ids.length,0);
 assert.equal(call('gale-profiles','set_enabled',{id:listed.profiles[0].id,enabled:true}).error,'NATIVE_VALIDATION_REQUIRED');
 assert.equal(call('gale-profiles','import',{content:direct}).added,1);
 const native=call('gale-profiles','list').profiles.find(p=>p.name==='NativeTest');
 const validated=call('gale-profiles','validate',{id:native.id});assert.equal(validated.passed,true);assert.equal(validated.handshake_tested,false);assert.equal(call('gale-profiles','set_enabled',{id:native.id,enabled:true}).enabled,true);
 const blockedProbe=call('gale-profiles','benchmark',{id:native.id});assert.equal(blockedProbe.result.ok,false);assert.equal(blockedProbe.result.error,'PROBE_PRIVATE_ADDRESS_BLOCKED');
 console.log('PASS isolated store: import, dedup, redaction, permissions, unsafe directives, SSRF, retention, validation gate and native Xray acceptance');
}finally{
 // Fixed known test files only, within a generated /tmp/gale-test UUID directory.
 ssh(`rm -f ${dir}/state.json ${dir}/state.new ${dir}/store.lock; rmdir ${dir}`);
}
