import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {writeFileSync} from 'node:fs';
import {createSocket} from 'node:dgram';
if(!process.argv.includes('--owner-approved-persistent-guard-and-reboot')){console.log('No changes. Requires explicit owner approval: persistent fw4 forwarding/DNS guard, network boot coordinator, and one controlled reboot. Public traffic stays blocked until VPN is ready. SSH and LuCI remain local.');process.exit(0);}
function ssh(script,allowFailure=false){const r=spawnSync('ssh',['-o','BatchMode=yes','-o','ConnectTimeout=3','root@192.168.10.1','sh'],{input:script,encoding:'utf8',timeout:25000});if(!allowFailure)assert.equal(r.status,0,r.stderr);return r;}
function dnsQuery(){return new Promise((resolve,reject)=>{const socket=createSocket('udp4'),header=Buffer.alloc(12);header.writeUInt16BE(0x4741,0);header.writeUInt16BE(0x0100,2);header.writeUInt16BE(1,4);const q=Buffer.concat([header,Buffer.from([7,...Buffer.from('example'),3,...Buffer.from('com'),0,0,1,0,1])]);let timer=setTimeout(()=>{socket.close();reject(Error('LAN_DNS_TIMEOUT'))},12000);socket.once('error',e=>{clearTimeout(timer);socket.close();reject(e)});socket.once('message',message=>{clearTimeout(timer);socket.close();try{assert.equal(message.readUInt16BE(0),0x4741);assert.equal(message.readUInt16BE(2)&15,0);assert(message.readUInt16BE(6)>0);resolve(message.readUInt16BE(6))}catch(e){reject(e)}});socket.send(q,53,'192.168.10.1')})}
function ntpQuery(){return new Promise((resolve,reject)=>{const socket=createSocket('udp4'),q=Buffer.alloc(48);q[0]=35;q.writeUInt32BE((Math.floor(Date.now()/1000)+2208988800)>>>0,40);q.writeUInt32BE(1,44);let timer=setTimeout(()=>{socket.close();reject(Error('LAN_UDP_NTP_TIMEOUT'))},12000);socket.once('error',e=>{clearTimeout(timer);socket.close();reject(e)});socket.once('message',message=>{clearTimeout(timer);socket.close();try{assert(message.length>=48);assert.equal(message[0]&7,4);assert(message[1]>0&&message[1]<16);assert(message.subarray(24,32).equals(q.subarray(40,48)));resolve(true)}catch(e){reject(e)}});socket.send(q,123,'162.159.200.123')})}

let sequence=0;async function call(sid,obj,method,args={}){const r=await fetch('http://192.168.10.1/ubus',{method:'POST',signal:AbortSignal.timeout(10000),headers:{'Content-Type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++sequence,method:'call',params:[sid,obj,method,args]})});const b=await r.json();assert.equal(b.result?.[0],0);assert(!b.result[1]?.error,b.result[1]?.error);return b.result[1];}
let sid='',report={scope:'persistent_guard_and_reboot',completed:false};
try{
 const beforeBoot=ssh('cat /proc/sys/kernel/random/boot_id\n').stdout.trim();
 ssh('/usr/share/gale/network-guard-install --owner-approved-persistent-guard\n');report.guard_installed=true;
 assert((await fetch('https://www.gstatic.com/generate_204',{signal:AbortSignal.timeout(15000)})).status===204);report.https_with_guard=true;
 report.dns_with_guard=await dnsQuery();report.udp_with_guard=await ntpQuery();
 console.log('Persistent guard verified; rebooting the router now.');
 ssh('(sleep 1; reboot) </dev/null >/dev/null 2>&1 &\n');
 let bootChanged=false,networkReady=false,started=Date.now(),lastProgress=0;
 for(let i=0;i<100;i++){
  await new Promise(r=>setTimeout(r,3000));const r=ssh('cat /proc/sys/kernel/random/boot_id\n',true);if(r.status!==0)continue;
  if(r.stdout.trim()===beforeBoot)continue;bootChanged=true;
  try{if(!sid)sid=(await call('0'.repeat(32),'session','login',{username:'root',password:'',timeout:300})).ubus_rpc_session;const status=await call(sid,'gale-connection','status');if(status.routing?.active&&status.health?.ok&&status.network_options?.boot_connect){networkReady=true;break;}}catch(e){sid='';}
  if(Date.now()-lastProgress>30000){console.log('Router is back; waiting for VPN network readiness.');lastProgress=Date.now();}
 }
 report.boot_id_changed=bootChanged;assert(bootChanged,'ROUTER_REBOOT_NOT_OBSERVED');assert(networkReady,'BOOT_NETWORK_NOT_READY_WITHIN_BUDGET');report.boot_network_ready_ms=Date.now()-started;
 assert((await fetch('https://www.gstatic.com/generate_204',{signal:AbortSignal.timeout(15000)})).status===204);report.client_https_restored=true;report.client_dns_answers=await dnsQuery();report.client_udp_ntp=await ntpQuery();
 const core=await call(sid,'gale-connection','status');assert(core.routing?.issues?.length===0);report.routing_integrity_verified=true;
 const luci=await fetch('http://192.168.10.1/cgi-bin/luci/',{signal:AbortSignal.timeout(10000)});assert(luci.ok||luci.status===403);report.luci_reachable=true;
 ssh('sha256sum -c /root/gale-migration-20261107/config.sha256\n');report.standard_configurations_unchanged=true;report.completed=true;
}catch(e){report.error=e.message;report.recovery='Local SSH: /usr/share/gale/network-guard-remove followed by /usr/share/gale/routing-rollback restores ordinary routing.';process.exitCode=1;}
finally{if(sid)try{await call(sid,'session','destroy')}catch(e){}writeFileSync('docs/network-persistence-result.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report));}
