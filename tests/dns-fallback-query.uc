import {create,AF_INET,SOCK_DGRAM} from 'socket';
let s=create(AF_INET,SOCK_DGRAM,0);assert(s.connect('127.0.0.1',15353),'DNS_FIXTURE_CONNECT_FAILED');
let bytes=[71,65,1,0,0,1,0,0,0,0,0,0,4,103,97,108,101,4,116,101,115,116,0,0,1,0,1],q=join('',map(bytes,n=>chr(n))),start=clock(true);s.send(q);let r=s.recv(2048),end=clock(true);s.close();
assert(r&&length(r)>12&&ord(r,0)==71&&ord(r,1)==65&&(ord(r,3)&15)==0,'DNS_FALLBACK_FAILED');assert(ord(r,6)*256+ord(r,7)>0,'DNS_FALLBACK_NO_ANSWER');let ms=(end[0]-start[0])*1000+(end[1]-start[1])/1000000;assert(ms>=1500&&ms<7000,'DNS_TIMEOUT_POLICY_NOT_OBSERVED');print({ordered_dns_failover:true,first_resolver:'silent_loopback_fixture',second_resolver:'controlled_loopback_fixture',elapsed_ms:ms,physical_LAN_changed:false});
