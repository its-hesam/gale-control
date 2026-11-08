import {validate_extra} from '/usr/share/gale/lib/xhttp-extra.uc';
import { writefile, readfile, mkdtemp, unlink, rmdir } from 'fs';
import {core_path} from '/usr/share/gale/lib/cores.uc';
function needs(ok,code) {if(!ok)die(code);}
export function xray_config(profile, policy) {
 let m=profile.model,p=m.parameters,proto=m.protocol;
 needs(proto in ['vless','vmess','trojan','ss','socks5','http','https'],'XRAY_PROTOCOL_NOT_IMPLEMENTED');
 let known=proto=='vmess' ? ['v','ps','add','port','id','aid','net','type','host','path','tls','sni','alpn','fp','scy','allowInsecure','authority','serviceName','mode'] : ['type','security','encryption','sni','fp','pbk','sid','spx','flow','path','host','mode','alpn','serviceName','authority','extra','allowInsecure','packetEncoding','headerType'];
 for(let key in keys(p)) needs(key in known,'UNMAPPED_PARAMETER');
 if(exists(p,'allowInsecure'))needs(p.allowInsecure in ['0','1','false','true',false,true],'BAD_ALLOW_INSECURE');
 let insecure=profile.tls_mode=='strict'?false:profile.tls_mode=='insecure'?true:exists(p,'allowInsecure') ? p.allowInsecure in ['1','true',true] : !!policy?.allow_insecure;
 needs(!p.packetEncoding,'UNMAPPED_PACKET_ENCODING');
 let outbound={tag:'vpn',protocol:proto=='ss' ? 'shadowsocks' : proto in ['socks5','http','https'] ? (proto=='socks5' ? 'socks' : 'http') : proto,settings:{}};
 let host=m.endpoint.host,port=m.endpoint.port;
 if(proto in ['vless','vmess']) {
  let user=proto=='vless' ? {id:m.credentials,encryption:p.encryption || 'none'} : {id:m.credentials.id,alterId:p.aid ? +p.aid : 0,security:p.scy || 'auto'};
  if(p.flow)user.flow=p.flow;
  outbound.settings={vnext:[{address:host,port:port,users:[user]}]};
 } else if(proto=='trojan') outbound.settings={servers:[{address:host,port:port,password:m.credentials}]};
 else if(proto=='ss') {
  let sep=index(m.credentials,':');needs(sep>0,'BAD_SHADOWSOCKS_CREDENTIAL');
  outbound.settings={servers:[{address:host,port:port,method:substr(m.credentials,0,sep),password:substr(m.credentials,sep+1)}]};
 } else {
  let server={address:host,port:port};
  if(m.credentials) {let sep=index(m.credentials,':');needs(sep>=0,'PROXY_USER_PASSWORD_REQUIRED');server.users=[{user:substr(m.credentials,0,sep),pass:substr(m.credentials,sep+1)}];}
  outbound.settings={servers:[server]};
 }
 let transport=m.transport=='raw' ? 'tcp' : m.transport;
 needs(transport in ['tcp','ws','grpc','httpupgrade','xhttp'],'TRANSPORT_NOT_IMPLEMENTED');
 if(proto=='vmess') needs(!p.type||p.type=='none'||(transport=='grpc'&&p.type in ['gun','multi'])||(transport=='tcp'&&p.type=='http'),'VMESS_HEADER_NOT_IMPLEMENTED');
 let security=m.security || 'none';
 needs(security in ['none','tls','reality'],'SECURITY_NOT_IMPLEMENTED');
 if(security=='reality') needs(proto=='vless','REALITY_COMBINATION_NOT_IMPLEMENTED');
 if(p.flow) needs(proto=='vless' && transport=='tcp' && security in ['tls','reality'],'FLOW_COMBINATION_NOT_IMPLEMENTED');
 let stream={network:transport,security:security};
 if(security=='tls') {
  stream.tlsSettings={serverName:p.sni || host,allowInsecure:insecure};
  if(p.fp)stream.tlsSettings.fingerprint=p.fp;
  if(p.alpn)stream.tlsSettings.alpn=split(p.alpn,',');
 }
 if(security=='reality') {
  needs(type(p.pbk)=='string' && !!match(p.pbk,/^[A-Za-z0-9_-]{43}$/),'REALITY_PUBLIC_KEY_REQUIRED');
  needs(!p.sid || !!match(p.sid,/^([0-9a-fA-F]{2}){0,8}$/),'BAD_REALITY_SHORT_ID');
  needs(!!p.sni,'REALITY_SERVER_NAME_REQUIRED');
  stream.realitySettings={serverName:p.sni,fingerprint:p.fp || 'chrome',publicKey:p.pbk,shortId:p.sid || ''};
  if(p.spx)stream.realitySettings.spiderX=p.spx;
 }
 if(transport=='ws') stream.wsSettings={path:p.path || '/',headers:p.host ? {Host:p.host} : {}};
 let header_type=p.headerType||(proto=='vmess'&&transport=='tcp'?p.type:null);
 if(header_type && header_type!='none')needs(transport=='tcp' && header_type=='http','HEADER_COMBINATION_NOT_IMPLEMENTED');
 if(transport=='tcp') {
  if(header_type=='http')stream.tcpSettings={header:{type:'http',request:{path:[p.path || '/'],headers:{Host:p.host ? split(p.host,',') : [host]}}}};
  else needs(!p.extra,'TCP_EXTRA_NOT_IMPLEMENTED');
 }
 if(transport=='grpc'){stream.grpcSettings={serviceName:(proto=='vmess'?p.path:p.serviceName)||'',authority:p.authority||p.host||p.sni||host};let mode=p.mode||(proto=='vmess'&&p.type!='none'?p.type:null);if(mode){needs(mode in ['gun','multi'],'BAD_GRPC_MODE');stream.grpcSettings.multiMode=mode=='multi';}if(stream.tlsSettings&&!p.alpn)stream.tlsSettings.alpn=['h2'];}
 if(transport=='httpupgrade') stream.httpupgradeSettings={path:p.path || '/',host:p.host || ''};
 if(transport=='xhttp') {
  stream.xhttpSettings={path:p.path || '/',host:p.host || '',mode:p.mode || 'auto'};
  if(p.extra) {let extra;try{extra=json(p.extra);}catch(e){die('BAD_XHTTP_EXTRA');}needs(type(extra)=='object','BAD_XHTTP_EXTRA');validate_extra(extra);stream.xhttpSettings.extra=extra;}
 }
 outbound.streamSettings=stream;
 return {log:{loglevel:'none'},inbounds:[],outbounds:[outbound]};
};
export function validate_xray(profile, policy, selected) {
 let config=selected?.config||xray_config(profile,policy),dir=mkdtemp('/tmp/gale-native-XXXXXX');
 if(!dir)die('NATIVE_TEMP_FAILED');
 let passed=false,code=-1,error=null;
 try {
  config.log.loglevel='warning';
  if(!writefile(dir+'/config.json',sprintf('%J',config)))die('NATIVE_TEMP_FAILED');
  code=system(['/usr/share/gale/capture',dir+'/output',selected?.binary||core_path('xray'),'run','-test','-c',dir+'/config.json'],5000);
  passed=code==0;
  if(!passed){
   let detail=lc(readfile(dir+'/output') || '');
   error=index(detail,'vless without tls')>=0 ? 'XRAY_PLAINTEXT_VLESS_REJECTED' : index(detail,'allowinsecure')>=0 ? 'XRAY_INSECURE_TLS_REMOVED' : match(detail,/invalid.*uuid/) ? 'CORE_INVALID_UUID' : match(detail,/unsupported.*(cipher|method)/) ? 'CORE_UNSUPPORTED_CIPHER' : 'CORE_SCHEMA_REJECTED';
  }
 } catch(e) {code=-1;}
 for(let file in ['config.json','output'])unlink(dir+'/'+file);
 rmdir(dir);
 return {passed:passed,exit_code:code,error:error,scope:'native_schema_only',handshake_tested:false};
};
