import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {readFileSync,writeFileSync} from 'node:fs';
import {createSocket} from 'node:dgram';
const udpTrial=process.argv.includes('--approved-90s-all-lan-udp');
if(!process.argv.includes('--approved-90s-all-lan')&&!udpTrial){
 console.log('Requires explicit owner approval: --approved-90s-all-lan (TCP only) or --approved-90s-all-lan-udp (TCP + UDP). Public IPv6 and other public protocols are blocked. Independent watchdog restores routing after about 90 seconds.');process.exit(0);
}
let sequence=0;const origin='http://192.168.10.1';
async function call(sid,obj,method,args={}){let r=await fetch(origin+'/ubus',{method:'POST',signal:AbortSignal.timeout(15000),headers:{'Content-Type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++sequence,method:'call',params:[sid,obj,method,args]})});let b=await r.json();assert.equal(b.result?.[0],0);assert(!b.result[1]?.error,b.result[1]?.error);return b.result[1]}
function ssh(command,input){const r=spawnSync('ssh',['-o','BatchMode=yes','root@192.168.10.1',command],{input,encoding:'utf8',timeout:25000,maxBuffer:1024*1024});assert.equal(r.status,0,r.stderr||r.stdout);return r.stdout}
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
function dnsQuery(){return new Promise((resolve,reject)=>{const socket=createSocket('udp4'),header=Buffer.alloc(12);header.writeUInt16BE(0x4741,0);header.writeUInt16BE(0x0100,2);header.writeUInt16BE(1,4);const q=Buffer.concat([header,Buffer.from([7,...Buffer.from('example'),3,...Buffer.from('com'),0,0,1,0,1])]);let timer=setTimeout(()=>{socket.close();reject(Error('LAN_DNS_TIMEOUT'))},12000);socket.once('error',e=>{clearTimeout(timer);socket.close();reject(e)});socket.once('message',message=>{clearTimeout(timer);socket.close();try{assert.equal(message.readUInt16BE(0),0x4741);assert.equal(message.readUInt16BE(2)&15,0);assert(message.readUInt16BE(6)>0);resolve(message.readUInt16BE(6))}catch(e){reject(e)}});socket.send(q,53,'192.168.10.1')})}
function ntpQuery(){return new Promise((resolve,reject)=>{const socket=createSocket('udp4'),q=Buffer.alloc(48);q[0]=35;q.writeUInt32BE((Math.floor(Date.now()/1000)+2208988800)>>>0,40);q.writeUInt32BE(1,44);let timer=setTimeout(()=>{socket.close();reject(Error('LAN_UDP_NTP_TIMEOUT'))},12000);socket.once('error',e=>{clearTimeout(timer);socket.close();reject(e)});socket.once('message',message=>{clearTimeout(timer);socket.close();try{assert(message.length>=48);assert.equal(message[0]&7,4);assert(message[1]>0&&message[1]<16);assert(message.subarray(24,32).equals(q.subarray(40,48)));resolve(true)}catch(e){reject(e)}});socket.send(q,123,'162.159.200.123')})}
let sid='',startedProxy=false,trialAttempted=false,trialStarted=0,report={scope:udpTrial?'temporary_all_LAN_IPv4_TCP_UDP_trial':'temporary_all_LAN_IPv4_TCP_trial',completed:false};
try{
 sid=(await call('0'.repeat(32),'session','login',{username:'root',password:'',timeout:900})).ubus_rpc_session;
 const policy=await call(sid,'gale-routing','status');assert.equal(policy.draft.default_action,'vpn');assert.equal(policy.draft.rules.length,0,'trial requires no device exceptions');assert(policy.lan.addresses.some(a=>a.address==='192.168.10.1'&&a.mask===24),'LAN differs from reviewed plan');
 let active=await call(sid,'gale-connection','status');
 if(!active.active){
  let catalog=await call(sid,'gale-profiles','list'),eligible=catalog.profiles.filter(p=>p.native_status==='passed'&&p.last_test?.ok&&catalog.observed_at-p.last_test.tested_at<=900);
  if(!eligible.length){await call(sid,'gale-jobs','start',{kind:'benchmark',limit:20});let finished=false;for(let i=0;i<120;i++){await sleep(2000);let j=(await call(sid,'gale-jobs','status')).job;if(j.state==='complete'){finished=true;break}assert(!['interrupted','cancelled'].includes(j.state),'benchmark did not complete')}assert(finished,'benchmark budget exceeded');catalog=await call(sid,'gale-profiles','list');eligible=catalog.profiles.filter(p=>p.native_status==='passed'&&p.last_test?.ok&&catalog.observed_at-p.last_test.tested_at<=900);}
  eligible.sort((a,b)=>a.last_test.latency_ms-b.last_test.latency_ms);assert(eligible.length,'NO_HEALTHY_PROXY_CANDIDATE');
  await call(sid,'gale-connection','connect',{id:eligible[0].id,auto_connect:false});startedProxy=true;
  let healthy=false;for(let i=0;i<40;i++){await sleep(1000);active=await call(sid,'gale-connection','status');if(active.running&&active.health?.ok){healthy=true;break}if(active.operation?.state==='failed')throw Error(active.operation.error)}assert(healthy,'LOCAL_PROXY_NOT_HEALTHY');
 }else assert(active.running&&active.health?.ok,'existing connection is unhealthy; it will not be replaced');
 if(udpTrial){if(active.udp)await sleep(11000);await call(sid,'gale-connection','test_udp',{kind:'ntp'});let passed=false;for(let i=0;i<20;i++){await sleep(1000);let status=await call(sid,'gale-connection','status');if(status.udp?.state!=='queued'){assert(status.udp?.ok&&status.udp?.method==='SOCKS5_UDP_NTP',status.udp?.error||'ACTIVE_UDP_NTP_NOT_VERIFIED');passed=true;break}}assert(passed,'UDP preflight budget exceeded');}
 const checks=JSON.parse(ssh(udpTrial?'ucode - udp':'ucode -',readFileSync('scripts/prepare-routing-test.uc','utf8').replace(/\r/g,'')));assert(checks.nft_dry_run&&checks.native.every(c=>c.native_schema),'PREPARATION_FAILED');
 const files='/etc/config/network /etc/config/firewall /etc/config/wireless /etc/config/dhcp /etc/config/dropbear /etc/config/uhttpd',before=ssh('sha256sum '+files);
 trialAttempted=true;trialStarted=Date.now();ssh(udpTrial?'/usr/share/gale/routing-apply --approved-90s-all-lan-udp':'/usr/share/gale/routing-apply --approved-90s-all-lan');await sleep(2500);
 report.dns_answers=await dnsQuery();if(udpTrial)report.client_public_udp_ntp=await ntpQuery();
 const https=await fetch('https://www.gstatic.com/generate_204',{signal:AbortSignal.timeout(20000),headers:{Connection:'close'}});assert.equal(https.status,204);report.client_https_204=true;
 const telemetry=await call(sid,'gale-status','status');assert(telemetry.system.memory.available>0);report.management_api_reachable=true;
 const luci=await fetch(origin+'/cgi-bin/luci/',{signal:AbortSignal.timeout(10000)});assert(luci.ok||luci.status===403);report.luci_reachable=true;
 const nft=JSON.parse(ssh('/usr/sbin/nft -j list table inet gale_preview'));let tcp=0,dns=0,udp=0;for(let item of nft.nftables){let r=item.rule;if(!r)continue;const count=r.expr.find(e=>e.counter)?.counter?.packets||0;if(r.chain==='ingress'&&r.expr.some(e=>e.tproxy)){if(r.expr.some(e=>e.match?.left?.meta?.key==='l4proto'&&(e.match.right==='udp'||e.match.right===17)))udp+=count;else tcp+=count;}if(r.chain==='dns')dns+=count;}assert(tcp>0&&dns>0,'interception counters did not increase');report.intercepted_tcp_packets=tcp;report.redirected_dns_packets=dns;if(udpTrial){assert(udp>0,'UDP interception counter did not increase');report.intercepted_udp_packets=udp;}
 assert.equal(ssh('sha256sum '+files),before,'standard configurations changed');report.standard_configurations_unchanged=true;report.completed=true;
}catch(e){report.error=e instanceof Error?e.message:'TRIAL_FAILED';process.exitCode=1;}
finally{
 if(trialAttempted){report.elapsed_ms=Date.now()-trialStarted;try{ssh('/usr/share/gale/routing-rollback');ssh('test ! -f /etc/gale/routing-test/armed; ! /usr/sbin/nft list table inet gale_preview >/dev/null 2>&1; ! ip -4 rule show | grep -q \'^31001:\'');report.rollback_verified=true;}catch(e){report.rollback_verified=false;report.recovery_note='Independent router watchdog remains the fallback; verify router access.';process.exitCode=1;}}
 if(sid){try{if(startedProxy)await call(sid,'gale-connection','disconnect');await call(sid,'session','destroy')}catch(e){report.session_cleanup_failed=true;}}
 writeFileSync(udpTrial?'docs/routing-trial-udp-result.json':'docs/routing-trial-result.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report));
}
