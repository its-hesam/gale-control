import {create,AF_INET,SOCK_STREAM,SOCK_DGRAM,MSG_WAITALL} from 'socket';
function bytes(values){return join('',map(values,n=>chr(n)));}
function need(ok,code){if(!ok)die(code);}
export function test_udp_proxy(kind,proxy_port,dns_ip,on_sent){
 proxy_port=proxy_port||17890;dns_ip=dns_ip||'1.1.1.1';need(proxy_port in [17890,17891],'BAD_UDP_PROXY_PORT');need(dns_ip in ['1.1.1.1','8.8.8.8','8.8.4.4'],'BAD_UDP_DNS_TARGET');
 kind=kind||'dns';need(kind in ['dns','ntp'],'BAD_UDP_TEST_KIND');
 let tcp=null,udp=null,result={ok:false,tested_at:time(),method:kind=='ntp'?'SOCKS5_UDP_NTP':'SOCKS5_UDP_DNS',packet_sent:false,packet_received:false,latency_ms:null,target:kind=='ntp'?'162.159.200.123:123':dns_ip+':53',answers:0,error:null};
 try{
  tcp=create(AF_INET,SOCK_STREAM,0);need(tcp&&tcp.connect('127.0.0.1',proxy_port),'UDP_PROXY_NOT_RUNNING');
  need(tcp.send(bytes([5,1,0]))==3,'SOCKS_GREETING_FAILED');need(tcp.recv(2,MSG_WAITALL)==bytes([5,0]),'SOCKS_AUTH_REJECTED');
  need(tcp.send(bytes([5,3,0,1,0,0,0,0,0,0]))==10,'UDP_ASSOCIATE_SEND_FAILED');
  let header=tcp.recv(4,MSG_WAITALL);need(header&&length(header)==4&&ord(header,1)==0,'UDP_ASSOCIATE_REJECTED');need(ord(header,3)==1,'UDP_RELAY_IPV4_REQUIRED');
  let address=tcp.recv(6,MSG_WAITALL);need(address&&length(address)==6,'BAD_UDP_RELAY_ADDRESS');let port=ord(address,4)*256+ord(address,5);need(port>=1024,'BAD_UDP_RELAY_PORT');
  udp=create(AF_INET,SOCK_DGRAM,0);need(udp&&udp.connect('127.0.0.1',port),'UDP_SOCKET_FAILED');
  let stamp=clock(true),request_id=stamp[1]%65536;
  let payload=bytes([(request_id>>8)&255,request_id&255,1,0,0,1,0,0,0,0,0,0,7])+'example'+bytes([3])+'com'+bytes([0,0,1,0,1]),prefix=bytes([0,0,0,1,...map(split(dns_ip,'.'),n=>+n),0,53]);
  if(kind=='ntp'){let request=[];for(let i=0;i<48;i++)push(request,0);request[0]=35;let seconds=time()+2208988800;for(let i=0;i<4;i++)request[40+i]=(seconds>>(24-i*8))&255;request[47]=1;payload=bytes(request);prefix=bytes([0,0,0,1,162,159,200,123,0,123]);}
  let packet=prefix+payload;
  need(udp.send(packet)==length(packet),'UDP_SEND_FAILED');result.packet_sent=true;let sent=clock(true);if(type(on_sent)=='function')on_sent();let response=udp.recv(2048);need(response&&length(response)>22,'UDP_NO_RESPONSE');need(ord(response,2)==0,'UDP_FRAGMENT_NOT_SUPPORTED');
  let address_kind=ord(response,3),offset=address_kind==1?10:address_kind==4?22:address_kind==3?7+ord(response,4):0;need(offset>0&&length(response)>=offset+12,'BAD_UDP_RESPONSE');
  if(kind=='ntp'){need(length(response)>=offset+48&&(ord(response,offset)&7)==4,'BAD_NTP_RESPONSE');need(ord(response,offset+1)>0&&ord(response,offset+1)<16,'NTP_UNSYNCHRONIZED_OR_RATE_LIMITED');need(substr(response,offset+24,8)==substr(payload,40,8),'NTP_ORIGIN_MISMATCH');result.ntp_response=true;}
  else {need(ord(response,offset)==((request_id>>8)&255)&&ord(response,offset+1)==(request_id&255),'DNS_RESPONSE_ID_MISMATCH');need((ord(response,offset+3)&15)==0,'UDP_DNS_RESPONSE_ERROR');result.answers=ord(response,offset+6)*256+ord(response,offset+7);need(result.answers>0,'UDP_DNS_NO_ANSWERS');}
  result.packet_received=true;let received=clock(true);result.latency_ms=(received[0]-sent[0])*1000+(received[1]-sent[1])/1000000;result.ok=true;
 }catch(e){result.error=match(e.message||'',/^[A-Z0-9_]+$/)?e.message:'UDP_PROBE_FAILED';}
 if(udp)udp.close();if(tcp)tcp.close();return result;
};
