import {extra_insecure} from '/usr/share/gale/lib/xhttp-extra.uc';
import {native_json_config} from '/usr/share/gale/lib/native-json.uc';
import {openvpn_config} from '/usr/share/gale/lib/openvpn.uc';
import {core_path,compatibility_xray} from '/usr/share/gale/lib/cores.uc';
import {wireguard_config} from '/usr/share/gale/lib/wireguard.uc';
import {xray_config,validate_xray} from '/usr/share/gale/lib/xray.uc';
import {mkdtemp,writefile,readfile,unlink,rmdir} from 'fs';
export function core_config(profile,policy) {
 if(profile.model.protocol=='native-json')return native_json_config(profile);
 if(profile.model.protocol=='openvpn')return openvpn_config(profile);
 if(profile.model.protocol=='wireguard')return wireguard_config(profile.model);
 let model=profile.model,params=model.parameters;
 if(model.protocol in ['hysteria2','tuic','anytls']){
  let known=['sni','alpn','allowInsecure','insecure','fp','disable_sni'];
  if(model.protocol=='hysteria2')known=[...known,'obfs','obfs-password'];
  if(model.protocol=='tuic')known=[...known,'congestion_control','udp_relay_mode'];
  for(let key in keys(params))if(!(key in known))die('UNMAPPED_PARAMETER');
  let flag=exists(params,'allowInsecure')?params.allowInsecure:params.insecure;
  if(exists(params,'allowInsecure')&&exists(params,'insecure')&&params.allowInsecure!=params.insecure)die('CONFLICTING_TLS_FLAGS');
  if(flag!=null && !(flag in ['0','1','false','true',false,true]))die('BAD_ALLOW_INSECURE');
  let insecure=profile.tls_mode=='strict'?false:profile.tls_mode=='insecure'?true:flag==null?!!policy?.allow_insecure:flag in ['1','true',true];
  let out={tag:'vpn',type:model.protocol,server:model.endpoint.host,server_port:model.endpoint.port,tls:{enabled:true,server_name:params.sni||model.endpoint.host,insecure:insecure}};
  if(params.alpn)out.tls.alpn=split(params.alpn,',');
  if(params.disable_sni!=null){if(!(params.disable_sni in ['0','1','false','true']))die('BAD_DISABLE_SNI');out.tls.disable_sni=params.disable_sni in ['1','true'];}
  if(params.fp){if(model.protocol!='anytls')die('UTLS_QUIC_NOT_SUPPORTED');out.tls.utls={enabled:true,fingerprint:params.fp};}
  if(model.protocol=='hysteria2'){
   out.password=model.credentials;
   if(params.obfs){if(params.obfs!='salamander'||!params['obfs-password'])die('BAD_HYSTERIA_OBFS');out.obfs={type:'salamander',password:params['obfs-password']};}
   else if(params['obfs-password'])die('BAD_HYSTERIA_OBFS');
  }else if(model.protocol=='tuic'){
   let sep=index(model.credentials,':');if(sep<0)die('TUIC_UUID_PASSWORD_REQUIRED');out.uuid=substr(model.credentials,0,sep);out.password=substr(model.credentials,sep+1);
   if(params.congestion_control){if(!(params.congestion_control in ['cubic','new_reno','bbr']))die('BAD_TUIC_CONGESTION');out.congestion_control=params.congestion_control;}
   if(params.udp_relay_mode){if(!(params.udp_relay_mode in ['native','quic']))die('BAD_TUIC_RELAY');out.udp_relay_mode=params.udp_relay_mode;}
  }else out.password=model.credentials;
  return {core:'sing-box',config:{log:{disabled:true},inbounds:[],outbounds:[out]}};
 }
 let base=xray_config(profile,policy),x=base.outbounds[0],tls=x.streamSettings.tlsSettings;
 if(model.protocol=='vless'&&model.security=='none')return {core:'xray',config:base,...compatibility_xray(),compatibility_reason:'explicit_plaintext_VLESS'};
 if(extra_insecure(x.streamSettings?.xhttpSettings?.extra))return {core:'xray',config:base,...compatibility_xray()};
 if(!tls?.allowInsecure)return {core:'xray',config:base};
 let m=profile.model,p=m.parameters,stream=x.streamSettings,t=stream.network;
 if(t in ['xhttp','grpc']||stream.tcpSettings?.header?.type=='http')return {core:'xray',config:base,...compatibility_xray()};
 if(!(t in ['tcp','ws','httpupgrade']))die('INSECURE_TRANSPORT_ADAPTER_REQUIRED');
 if(p.headerType && p.headerType!='none')die('SINGBOX_TCP_HEADER_NOT_IMPLEMENTED');
 let out={type:m.protocol=='ss'?'shadowsocks':m.protocol,tag:'vpn',server:m.endpoint.host,server_port:m.endpoint.port};
 if(m.protocol in ['vless','vmess']) {
  let user=x.settings.vnext[0].users[0];out.uuid=user.id;
  if(m.protocol=='vless') {if(user.encryption!='none')die('SINGBOX_VLESS_ENCRYPTION_NOT_IMPLEMENTED');if(user.flow)out.flow=user.flow;}
  else {out.security=user.security;out.alter_id=user.alterId;}
 } else if(m.protocol=='trojan')out.password=m.credentials;
 else die('INSECURE_PROTOCOL_ADAPTER_NOT_IMPLEMENTED');
 out.tls={enabled:true,server_name:tls.serverName,insecure:true};
 if(tls.alpn)out.tls.alpn=tls.alpn;
 if(tls.fingerprint)out.tls.utls={enabled:true,fingerprint:tls.fingerprint};
 if(t=='ws')out.transport={type:'ws',path:stream.wsSettings.path,headers:stream.wsSettings.headers};
 if(t=='grpc')out.transport={type:'grpc',service_name:stream.grpcSettings.serviceName};
 if(t=='httpupgrade')out.transport={type:'httpupgrade',path:stream.httpupgradeSettings.path,host:stream.httpupgradeSettings.host};
 return {core:'sing-box',config:{log:{disabled:true},inbounds:[],outbounds:[out]}};
};
export function validate_core(profile,policy) {
 let selected=core_config(profile,policy);
 if(selected.core=='xray')return {...validate_xray(profile,policy,selected),compatibility_version:selected.compatibility_version,core:'xray'};
 let dir=mkdtemp('/tmp/gale-native-XXXXXX'),passed=false,code=-1;
 if(!dir)die('NATIVE_TEMP_FAILED');
 try {writefile(dir+'/config.json',sprintf('%J',selected.config));code=system(['/usr/share/gale/capture',dir+'/output',selected.binary||core_path('sing-box'),'check','-c',dir+'/config.json'],5000);passed=code==0;}catch(e){}
 for(let f in ['config.json','output'])unlink(dir+'/'+f);rmdir(dir);
 return {passed:passed,feature_version:selected.feature_version||null,provider_tested:false,exit_code:code,error:passed?null:'SINGBOX_SCHEMA_REJECTED',core:'sing-box',scope:'native_schema_only',handshake_tested:false};
};
