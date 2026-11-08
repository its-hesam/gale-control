import assert from 'node:assert/strict';
import {createSocket} from 'node:dgram';
import {writeFileSync} from 'node:fs';
function dnsQuery(){return new Promise((resolve,reject)=>{const socket=createSocket('udp4'),header=Buffer.alloc(12);header.writeUInt16BE(0x4741,0);header.writeUInt16BE(0x0100,2);header.writeUInt16BE(1,4);const q=Buffer.concat([header,Buffer.from([7,...Buffer.from('example'),3,...Buffer.from('com'),0,0,1,0,1])]);let timer=setTimeout(()=>{socket.close();reject(Error('LAN_DNS_TIMEOUT'))},12000);socket.once('error',e=>{clearTimeout(timer);socket.close();reject(e)});socket.once('message',message=>{clearTimeout(timer);socket.close();try{assert.equal(message.readUInt16BE(0),0x4741);assert.equal(message.readUInt16BE(2)&15,0);assert(message.readUInt16BE(6)>0);resolve(message.readUInt16BE(6))}catch(e){reject(e)}});socket.send(q,53,'192.168.10.1')})}
function ntpQuery(){return new Promise((resolve,reject)=>{const socket=createSocket('udp4'),q=Buffer.alloc(48);q[0]=35;q.writeUInt32BE((Math.floor(Date.now()/1000)+2208988800)>>>0,40);q.writeUInt32BE(1,44);let timer=setTimeout(()=>{socket.close();reject(Error('LAN_UDP_NTP_TIMEOUT'))},12000);socket.once('error',e=>{clearTimeout(timer);socket.close();reject(e)});socket.once('message',message=>{clearTimeout(timer);socket.close();try{assert(message.length>=48);assert.equal(message[0]&7,4);assert(message[1]>0&&message[1]<16);assert(message.subarray(24,32).equals(q.subarray(40,48)));resolve(true)}catch(e){reject(e)}});socket.send(q,123,'162.159.200.123')})}

const answers=await dnsQuery(),ntp=await ntpQuery();
const https=await fetch('https://www.gstatic.com/generate_204',{signal:AbortSignal.timeout(15000)});assert.equal(https.status,204);
const trace=await(await fetch('https://1.1.1.1/cdn-cgi/trace',{signal:AbortSignal.timeout(15000)})).text(),fields=Object.fromEntries(trace.trim().split('\n').map(l=>l.split('=')));
assert(fields.ip&&fields.ip!=='178.131.99.134');
const report={scope:'active_all_LAN_IPv4_session',dns_answers:answers,udp_ntp_verified:ntp,https_204:true,client_egress_ip:fields.ip,client_egress_country:fields.loc,public_ipv6:'blocked_by_policy',boot_reconnect:false};
writeFileSync('docs/lan-session-result.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report));
