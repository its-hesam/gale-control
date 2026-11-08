import {managed_feature_core} from '/usr/share/gale/lib/cores.uc';
function tokens(line){let result=[],word='',quote=null,escape=false,started=false;for(let i=0;i<length(line);i++){let c=substr(line,i,1);if(escape){word+=c;escape=false;started=true;continue;}if(c=='\\'&&quote!="'"){escape=true;continue;}if(quote){if(c==quote)quote=null;else word+=c;started=true;continue;}if(c=='"'||c=="'"){quote=c;started=true;continue;}if(c=='#'&&!started)break;if(match(c,/\s/)){if(started){push(result,word);word='';started=false;}continue;}word+=c;started=true;}if(quote||escape)die('BAD_OPENVPN_QUOTING');if(started)push(result,word);return result;}
export function parse_openvpn(raw){
 let remotes=[],options=[],blocks={},block=null,content=[];
 for(let input in split(raw,/\r?\n/)){
  let line=trim(input);if(block){if(line=='</'+block+'>'){blocks[block]=join('\n',content);block=null;content=[];}else push(content,input);continue;}
  if(!length(line)||match(line,/^[#;]/))continue;
  let start=match(line,/^<([a-z0-9-]+)>$/);if(start){if(!(start[1] in ['ca','cert','key','tls-auth','tls-crypt','tls-crypt-v2','extra-certs','auth-user-pass']))die('OPENVPN_INLINE_BLOCK_NOT_SUPPORTED');if(exists(blocks,start[1]))die('DUPLICATE_OPENVPN_BLOCK');block=start[1];continue;}
  let fields=tokens(line),name=replace(fields[0],/^--/,'');
  if(name in ['up','down','route-up','route-pre-down','ipchange','script-security','plugin','config','management','daemon','cd','log','log-append','status','writepid','tls-verify','auth-user-pass-verify','client-connect','client-disconnect','learn-address','iproute','askpass','chroot','user','group'])die('UNSAFE_OPENVPN_DIRECTIVE');
  push(options,{name:name,values:slice(fields,1)});
  if(name=='remote'){
   if(length(fields)<2||length(fields)>4||!match(fields[1],/^[a-zA-Z0-9][a-zA-Z0-9.:-]{0,252}$/))die('BAD_OPENVPN_REMOTE');
   if(fields[3]&&!(fields[3] in ['udp','udp4','udp6','tcp','tcp-client','tcp4-client','tcp6-client']))die('OPENVPN_PROTO_NOT_SUPPORTED');
   let port=fields[2]||'1194';if(!match(port,/^[0-9]+$/)||+port<1||+port>65535)die('BAD_OPENVPN_REMOTE_PORT');
   push(remotes,{host:lc(fields[1]),port:+port,protocol:fields[3]||null});
  }
 }
 if(block)die('UNCLOSED_OPENVPN_BLOCK');if(!length(remotes))die('OPENVPN_REMOTE_REQUIRED');if(length(remotes)>16)die('OPENVPN_REMOTE_LIMIT');
 let proto='udp';for(let option in options)if(option.name=='proto'){proto=option.values[0];if(!(proto in ['udp','udp4','udp6','tcp','tcp-client','tcp4-client','tcp6-client']))die('OPENVPN_PROTO_NOT_SUPPORTED');}
 return {protocol:'openvpn',name:'OpenVPN',transport:proto,security:'tls',endpoint:{host:remotes[0].host,port:remotes[0].port},credentials:{inline_material:blocks},parameters:{options:options,remotes:remotes}};
};
export function review_openvpn(model){
 let known=['client','tls-client','dev','dev-type','proto','remote','remote-random','resolv-retry','connect-retry','connect-retry-max','connect-timeout','nobind','persist-key','persist-tun','remote-cert-tls','verify-x509-name','cipher','data-ciphers','data-ciphers-fallback','auth','tls-version-min','tls-version-max','tls-cipher','tls-ciphersuites','key-direction','auth-nocache','auth-retry','auth-user-pass','reneg-sec','hand-window','tls-timeout','ping','ping-restart','ping-exit','explicit-exit-notify','verb','mute','tun-mtu','fragment','mssfix','comp-lzo','compress','allow-compression','route','route-gateway','redirect-gateway','route-nopull','route-metric','dhcp-option','ifconfig','ifconfig-ipv6','route-ipv6','ca','cert','key','tls-auth','tls-crypt','tls-crypt-v2','extra-certs','topology','replay-window','reneg-bytes','reneg-pkts','pull-filter','remote-cert-eku','remote-cert-ku','tls-cert-profile','peer-fingerprint','disable-dco','pull'];
 let credentials_required=false;
 for(let option in model.parameters.options){
  if(!(option.name in known))die('OPENVPN_UNMAPPED_DIRECTIVE');
  if(option.name=='auth-user-pass'){credentials_required=true;if(length(option.values)&&option.values[0]!='[inline]')die('OPENVPN_EXTERNAL_AUTH_FILE_NOT_ALLOWED');}
  if(option.name in ['ca','cert','key','tls-auth','tls-crypt','tls-crypt-v2'])if(option.values[0]!='[inline]')die('OPENVPN_INLINE_MATERIAL_REQUIRED');
 }
 return {core:'openvpn',static_review_passed:true,credentials_required:credentials_required||!!model.credentials.inline_material['auth-user-pass'],remote_count:length(model.parameters.remotes),inline_ca:!!model.credentials.inline_material.ca,scope:'static_review_only',native_schema_verified:false,handshake_tested:false,network_activation_required:true};
};

function ipv4_prefix(ip,mask){let octets=split(ip||'','.');if(length(octets)!=4)die('BAD_OPENVPN_ADDRESS');for(let n in octets)if(!match(n,/^[0-9]{1,3}$/)||+n>255)die('BAD_OPENVPN_ADDRESS');if(!mask)return ip+'/32';let m=split(mask,'.'),bits=0,zero=false;if(length(m)!=4)die('BAD_OPENVPN_NETMASK');for(let n in m){if(!match(n,/^[0-9]{1,3}$/)||+n>255)die('BAD_OPENVPN_NETMASK');for(let b=7;b>=0;b--){if((+n>>b)&1){if(zero)die('BAD_OPENVPN_NETMASK');bits++;}else zero=true;}}return ip+'/'+bits;}
function number_value(value,min,max){if(!match(value||'',/^[0-9]+$/)||+value<min||+value>max)die('BAD_OPENVPN_NUMERIC_OPTION');return +value;}
export function openvpn_config(profile){
 let m=profile.model,review=review_openvpn(m),material=m.credentials.inline_material;
 if(!material.ca)die('OPENVPN_INLINE_CA_REQUIRED');
 let ep={type:'openvpn-client',tag:'vpn',mode:'tls',system:false,network:replace(m.transport,/-client$/,''),servers:[],tls:{certificate:split(material.ca,'\n'),remote_certificate_tls:'server'},allow_compression:'no'};
 for(let remote in m.parameters.remotes)push(ep.servers,{server:remote.host,server_port:remote.port,network:replace(remote.protocol||m.transport,/-client$/,'')});
 if(!!material.cert!=!!material.key)die('OPENVPN_CERT_KEY_PAIR_REQUIRED');
 if(material.cert){ep.tls.client_certificate=split(material.cert,'\n');ep.tls.client_key=split(material.key,'\n');}
 for(let name in ['tls-auth','tls-crypt','tls-crypt-v2'])if(material[name]){if(ep.tls.control_wrap)die('CONFLICTING_OPENVPN_CONTROL_KEYS');ep.tls.control_wrap={type:replace(name,/-/g,'_'),key:split(material[name],'\n')};}
 if(material['extra-certs']){if(!ep.tls.client_certificate)die('OPENVPN_CLIENT_CERT_REQUIRED');ep.tls.client_certificate=[...ep.tls.client_certificate,...split(material['extra-certs'],'\n')];}
 let auth=profile.openvpn_auth;
 if(material['auth-user-pass']){let lines=split(trim(material['auth-user-pass']),'\n');if(length(lines)!=2)die('BAD_OPENVPN_INLINE_AUTH');auth={username:trim(lines[0]),password:trim(lines[1])};}
 if(review.credentials_required){if(!auth?.username||!auth?.password)die('OPENVPN_CREDENTIALS_REQUIRED');ep.username=auth.username;ep.password=auth.password;}
 let notes=[],dns=[];
 let strings={'cipher':'cipher','auth':'auth','data-ciphers-fallback':'data_ciphers_fallback','tls-cipher':'cipher','tls-cert-profile':'certificate_profile','remote-cert-eku':'remote_certificate_eku','tls-version-min':'version_min','tls-version-max':'version_max'};
 for(let option in m.parameters.options){let n=option.name,v=option.values,a=v[0];
  if(n in ['client','tls-client','ca','cert','key','tls-auth','tls-crypt','tls-crypt-v2','auth-user-pass','remote','proto'])continue;
  if(n in ['persist-key','persist-tun','resolv-retry','nobind','verb','mute','auth-nocache','disable-dco','pull','connect-retry','connect-retry-max','connect-timeout','remote-cert-tls']){push(notes,'managed_lifecycle:'+n);continue;}
  if(n=='dev'||n=='dev-type'){if(a=='tap')die('OPENVPN_TAP_NOT_SUPPORTED');continue;}
  if(n=='data-ciphers'){ep.data_ciphers=split(a,':');continue;}
  if(exists(strings,n)){if(n in ['tls-cipher','tls-cert-profile','remote-cert-eku','tls-version-min','tls-version-max'])ep.tls[strings[n]]=a;else ep[strings[n]]=a;continue;}
  if(n=='verify-x509-name'){ep.tls.server_name=a;ep.tls.server_name_type=v[1]||'subject';continue;}
  if(n=='key-direction'){if(!ep.tls.control_wrap||!(a in ['0','1']))die('BAD_OPENVPN_KEY_DIRECTION');ep.tls.control_wrap.direction=a=='1'?'client':'server';continue;}
  if(n=='peer-fingerprint'){ep.tls.peer_fingerprint=[lc(replace(a,/:/g,''))];continue;}
  if(n=='remote-cert-ku'){ep.tls.remote_certificate_ku=v;continue;}
  if(n=='remote-random'){ep.remote_random=true;continue;}
  if(n=='topology'){ep.topology=a;continue;}
  if(n=='tun-mtu'){ep.mtu=number_value(a,576,9000);continue;}
  if(n in ['ping','ping-restart','ping-exit','reneg-sec','hand-window','tls-timeout']){if(a=='0'&&n=='reneg-sec'){ep.renegotiate_disabled=true;continue;}if(a=='0'&&n=='ping-restart'){ep.ping_restart_disabled=true;continue;}let fields={'ping':'ping_interval','ping-restart':'ping_restart','ping-exit':'ping_restart','reneg-sec':'renegotiate_interval','hand-window':'handshake_window','tls-timeout':'tls_timeout'};ep[fields[n]]=number_value(a,0,86400)+'s';continue;}
  if(n in ['fragment','reneg-bytes','reneg-pkts','route-metric']){let fields={'fragment':'fragment','reneg-bytes':'renegotiate_bytes','reneg-pkts':'renegotiate_packets','route-metric':'route_metric'};ep[fields[n]]=number_value(a,0,2147483647);continue;}
  if(n=='mssfix'){if(a=='0')ep.mss_fix_disabled=true;else ep.mss_fix=number_value(a||'1450',576,9000);if(v[1]){if(v[1]!='mtu')die('BAD_OPENVPN_MSSFIX');ep.mss_fix_mode='mtu';}continue;}
  if(n=='replay-window'){ep.replay_window=number_value(a,1,65535);if(v[1])ep.replay_window_time=number_value(v[1],1,86400)+'s';continue;}
  if(n=='auth-retry'){ep.auth_retry=a;continue;}
  if(n=='explicit-exit-notify'){ep.explicit_exit_notify=number_value(a||'1',0,10);continue;}
  if(n=='comp-lzo'){ep.compression_lzo=a||'adaptive';continue;}
  if(n=='compress'){ep.compression=a||'stub';continue;}
  if(n=='allow-compression'){ep.allow_compression=a;continue;}
  if(n=='route-nopull'){ep.route_no_pull=true;continue;}
  if(n=='route-gateway'){ep.route_gateway=a;continue;}
  if(n=='redirect-gateway'){ep.redirect_gateway=true;ep.redirect_gateway_flags=v;continue;}
  if(n=='pull-filter'){if(length(v)!=2||!(a in ['accept','ignore','reject']))die('BAD_OPENVPN_PULL_FILTER');ep.pull_filters=ep.pull_filters||[];push(ep.pull_filters,{action:a,text:v[1]});continue;}
  if(n=='dhcp-option'){if(a=='DNS'){if(!match(v[1]||'',/^[0-9a-fA-F:.]+$/))die('BAD_OPENVPN_DNS');push(dns,v[1]);}else push(notes,'not_applied_dhcp_option:'+a);continue;}
  if(n=='ifconfig'){if(length(v)!=2)die('BAD_OPENVPN_IFCONFIG');ep.address=ep.address||[];if(ep.topology=='subnet')push(ep.address,ipv4_prefix(a,v[1]));else{push(ep.address,ipv4_prefix(a));ep.peer_address=v[1];}continue;}
  if(n=='ifconfig-ipv6'){if(length(v)!=2)die('BAD_OPENVPN_IFCONFIG');ep.address=ep.address||[];push(ep.address,a);ep.peer_address_ipv6=v[1];continue;}
  if(n=='route'){if(v[2]&&v[2]!='vpn_gateway')die('OPENVPN_ROUTE_GATEWAY_MAPPING_REQUIRED');ep.routes=ep.routes||[];push(ep.routes,ipv4_prefix(a,v[1]));continue;}
  if(n=='route-ipv6'){if(v[1]&&v[1]!='vpn_gateway')die('OPENVPN_ROUTE_GATEWAY_MAPPING_REQUIRED');ep.routes=ep.routes||[];push(ep.routes,a);continue;}
  if(n=='tls-ciphersuites')die('OPENVPN_TLS_CIPHERSUITES_MAPPING_REQUIRED');
  die('OPENVPN_UNMAPPED_DIRECTIVE');
 }
 let resolver=length(dns)?{type:'udp',tag:'ovpn-dns',server:dns[0],detour:'vpn'}:{type:'openvpn',tag:'ovpn-dns',endpoint:'vpn',accept_default_resolvers:true};
 let servers=length(dns)?[resolver]:[resolver,{type:'udp',tag:'ovpn-fallback',server:'1.1.1.1',detour:'vpn'}];
 let dns_config={servers:servers,final:length(dns)?'ovpn-dns':'ovpn-fallback',strategy:'prefer_ipv4'};if(!length(dns))dns_config.rules=[{preferred_by:'ovpn-dns',action:'route',server:'ovpn-dns'}];
 return {core:'sing-box',...managed_feature_core('sing-box','1.14.4','OpenVPN_client'),notes:notes,provider_tested:false,config:{log:{disabled:true},endpoints:[ep],outbounds:[],inbounds:[],dns:dns_config,route:{final:'vpn',default_domain_resolver:length(dns)?'ovpn-dns':'ovpn-fallback'}}};
};
