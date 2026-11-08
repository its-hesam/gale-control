import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
let n=0;async function call(sid,obj,method,args={}){let r=await fetch('http://192.168.10.1/ubus',{method:'POST',signal:AbortSignal.timeout(15000),headers:{'Content-Type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++n,method:'call',params:[sid,obj,method,args]})});let b=await r.json();assert.equal(b.result?.[0],0);assert(!b.result[1]?.error,b.result[1]?.error);return b.result[1]}
function ssh(command,input,allowOpenSocketTimeout=false){const r=spawnSync('ssh',['-o','BatchMode=yes','root@192.168.10.1',command],{input,timeout:20000,maxBuffer:16384});assert(r.status===0||(allowOpenSocketTimeout&&r.status===124&&r.stdout.length>14),r.stderr.toString()||'SSH/DNS command failed');return r.stdout}
const sid=(await call('0'.repeat(32),'session','login',{username:'root',password:'',timeout:180})).ubus_rpc_session;let started=false,dir='';
try{
 assert(!(await call(sid,'gale-connection','status')).active,'requires idle connection');
 const p=(await call(sid,'gale-profiles','list')).profiles.find(p=>p.native_status==='passed'&&p.last_test?.ok&&p.protocol==='vmess');assert(p);
 await call(sid,'gale-connection','connect',{id:p.id,auto_connect:false});started=true;let ok=false;
 for(let i=0;i<30;i++){await new Promise(r=>setTimeout(r,1000));const s=await call(sid,'gale-connection','status');if(s.health?.ok&&s.running){ok=true;break}}assert(ok,'underlying VPN proxy unavailable');
 const bootstrap=`import {mkdtemp,writefile,popen} from 'fs';import {dns_bridge_config} from '/usr/share/gale/lib/network-plan.uc';import {core_path} from '/usr/share/gale/lib/cores.uc';let dir=mkdtemp('/tmp/gale-dns-test-XXXXXX');writefile(dir+'/config.json',sprintf('%J',dns_bridge_config()));let child=popen('/usr/bin/timeout 45 '+core_path('sing-box')+' run -c '+dir+'/config.json </dev/null >/dev/null 2>&1 &','r');if(child)child.close();print({dir:dir});`;
 dir=JSON.parse(ssh('ucode -',bootstrap).toString()).dir;assert.match(dir,/^\/tmp\/gale-dns-test-[a-zA-Z0-9]+$/);await new Promise(r=>setTimeout(r,1500));
 const labels=Buffer.from([7,...Buffer.from('example'),3,...Buffer.from('com'),0]),header=Buffer.alloc(12);header.writeUInt16BE(0x4741,0);header.writeUInt16BE(0x0100,2);header.writeUInt16BE(1,4);const q=Buffer.concat([header,labels,Buffer.from([0,1,0,1])]),len=Buffer.alloc(2);len.writeUInt16BE(q.length);
 const response=ssh('timeout 12 nc 127.0.0.1 5353',Buffer.concat([len,q]),true);assert(response.length>14,'empty DNS TCP response');const body=response.subarray(2);assert.equal(body.readUInt16BE(0),0x4741);assert.equal(body.readUInt16BE(2)&15,0);assert(body.readUInt16BE(6)>0,'DNS response contains no answers');
 console.log(JSON.stringify({dns_tcp_query:true,answers:body.readUInt16BE(6),transport:'DoH_via_VPN_loopback_proxy',client_network_redirected:false,dns_leak_tested:false}));
}finally{
 if(dir)ssh(`for file in /proc/[0-9]*/cmdline; do if tr '\\000' '\\n' <"$file" 2>/dev/null | grep -Fxq '${dir}/config.json'; then pid=\${file#/proc/}; pid=\${pid%/cmdline}; kill "$pid" 2>/dev/null || true; fi; done; rm -f '${dir}/config.json'; rmdir '${dir}'`);
 if(started)await call(sid,'gale-connection','disconnect');await call(sid,'session','destroy');
}
