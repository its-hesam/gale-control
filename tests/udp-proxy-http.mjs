import assert from 'node:assert/strict';
import {spawn,spawnSync} from 'node:child_process';
let n=0;async function call(sid,obj,method,args={}){let r=await fetch('http://192.168.10.1/ubus',{method:'POST',signal:AbortSignal.timeout(15000),headers:{'Content-Type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++n,method:'call',params:[sid,obj,method,args]})});let b=await r.json();assert.equal(b.result?.[0],0);assert(!b.result[1]?.error,b.result[1]?.error);return b.result[1]}
let sid='',started=false,control;
try{
 sid=(await call('0'.repeat(32),'session','login',{username:'root',password:'',timeout:180})).ubus_rpc_session;
 assert(!(await call(sid,'gale-connection','status')).active,'requires idle connection');
 const p=(await call(sid,'gale-profiles','list')).profiles.find(p=>p.protocol==='vmess'&&p.native_status==='passed'&&p.last_test?.ok);assert(p);
 await call(sid,'gale-connection','connect',{id:p.id,auto_connect:false});started=true;let healthy=false;
 for(let i=0;i<40;i++){await new Promise(r=>setTimeout(r,1000));let s=await call(sid,'gale-connection','status');if(s.running&&s.health?.ok){healthy=true;break}}assert(healthy,'VPN proxy not healthy');
 control=spawn('ssh',['-o','BatchMode=yes','root@192.168.10.1','timeout 30 nc 127.0.0.1 17890']);let incoming=Buffer.alloc(0),wake;control.stdout.on('data',b=>{incoming=Buffer.concat([incoming,b]);wake?.()});
 async function read(size){const until=Date.now()+10000;while(incoming.length<size){assert(Date.now()<until,'SOCKS control timeout');await new Promise(resolve=>{let timer=setTimeout(()=>{wake=undefined;resolve()},100);wake=()=>{clearTimeout(timer);wake=undefined;resolve()}})}const b=incoming.subarray(0,size);incoming=incoming.subarray(size);return b}
 control.stdin.write(Buffer.from([5,1,0]));assert.deepEqual([...await read(2)],[5,0]);control.stdin.write(Buffer.from([5,3,0,1,0,0,0,0,0,0]));const h=await read(4);assert.equal(h[1],0,'UDP ASSOCIATE rejected');assert.equal(h[3],1,'IPv4 UDP relay expected');const addr=await read(6),port=addr.readUInt16BE(4);assert(port>0);
 const header=Buffer.alloc(12);header.writeUInt16BE(0x4741,0);header.writeUInt16BE(0x0100,2);header.writeUInt16BE(1,4);const dns=Buffer.concat([header,Buffer.from([7,...Buffer.from('example'),3,...Buffer.from('com'),0,0,1,0,1])]);const packet=Buffer.concat([Buffer.from([0,0,0,1,1,1,1,1,0,53]),dns]);
 const r=spawnSync('ssh',['-o','BatchMode=yes','root@192.168.10.1',`timeout 8 ucode /usr/share/gale/udp-relay-request.uc ${port}`],{input:packet.toString('base64'),timeout:12000,maxBuffer:4096});assert([0,124].includes(r.status),r.stderr.toString());const response=Buffer.from(JSON.parse(r.stdout.toString()).response,'base64');assert(response.length>22,'empty UDP relay response');assert.equal(response[2],0,'fragmented UDP unsupported');const offset=response[3]===1?10:response[3]===4?22:response[3]===3?7+response[4]:0;assert(offset>0);const answer=response.subarray(offset);assert.equal(answer.readUInt16BE(0),0x4741);assert.equal(answer.readUInt16BE(2)&15,0);assert(answer.readUInt16BE(6)>0);
 console.log(JSON.stringify({udp_dns_through_vpn:true,protocol:p.protocol,answers:answer.readUInt16BE(6),network_routing_changed:false}));
}finally{control?.kill();if(sid){if(started)await call(sid,'gale-connection','disconnect');await call(sid,'session','destroy')}}
