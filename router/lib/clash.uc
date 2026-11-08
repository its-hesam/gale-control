function need(ok,code){if(!ok)die(code);}
export function clash_model(p){
 need(type(p)=='object'&&type(p.type)=='string','BAD_CLASH_PROXY');
 let known=['name','type','server','port','uuid','alterId','cipher','password','username','tls','servername','sni','skip-cert-verify','client-fingerprint','fingerprint','alpn','network','ws-opts','grpc-opts','http-upgrade-opts','reality-opts','flow','packet-encoding','udp','udp-over-tcp','tfo','mptcp','ip-version','interface-name','routing-mark','private-key','public-key','pre-shared-key','ip','ipv6','dns','mtu','allowed-ips','persistent-keepalive','obfs','obfs-password','congestion-controller','udp-relay-mode','reduce-rtt','disable-sni'];
 for(let k in keys(p))need(k in known,'UNMAPPED_CLASH_FIELD');
 need(type(p.server)=='string'&&length(p.server)<=253&&match(p.server,/^[A-Za-z0-9][A-Za-z0-9.:-]*$/),'BAD_CLASH_SERVER');need(type(p.port) in ['int','string']&&match(''+p.port,/^[0-9]+$/)&&+p.port>0&&+p.port<=65535,'BAD_CLASH_PORT');
 for(let k in ['udp-over-tcp','tfo','mptcp','interface-name','routing-mark','ip-version','reduce-rtt'])if(p[k])die('CLASH_OPTION_MAPPING_REQUIRED');
 let proto=p.type=='ss'?'ss':p.type=='socks5'?'socks5':p.type,transport=p.network||'tcp',security=p.tls||proto in ['trojan','hysteria2','tuic','anytls']?'tls':'none',params={},credential;
 need(proto in ['vless','vmess','trojan','ss','socks5','http','hysteria2','tuic','anytls','wireguard'],'CLASH_PROTOCOL_NOT_SUPPORTED');
 if(proto=='wireguard'){
  need(p['private-key']&&p['public-key']&&p.ip,'BAD_CLASH_WIREGUARD');let iface={PrivateKey:p['private-key'],Address:p.ip+(index(p.ip,'/')>=0?'':'/32')};if(p.ipv6)iface.Address+=','+p.ipv6+(index(p.ipv6,'/')>=0?'':'/128');if(p.dns)iface.DNS=type(p.dns)=='array'?join(',',p.dns):p.dns;if(p.mtu)iface.MTU=''+p.mtu;
  let peer={PublicKey:p['public-key'],Endpoint:p.server+':'+p.port,AllowedIPs:p['allowed-ips']?(type(p['allowed-ips'])=='array'?join(',',p['allowed-ips']):p['allowed-ips']):'0.0.0.0/0,::/0'};if(p['pre-shared-key'])peer.PresharedKey=p['pre-shared-key'];if(p['persistent-keepalive'])peer.PersistentKeepalive=''+p['persistent-keepalive'];return {protocol:proto,name:p.name||'WireGuard',transport:'udp',security:'wireguard',endpoint:{host:p.server,port:+p.port},credentials:{private_key:p['private-key']},parameters:{interface:iface,peers:[peer]}};
 }
 if(proto in ['vless','vmess']){need(type(p.uuid)=='string','CLASH_UUID_REQUIRED');credential=proto=='vmess'?{id:p.uuid}:p.uuid;if(proto=='vmess'){params.scy=p.cipher||'auto';params.aid=''+(p.alterId||0);params.type='none';}else params.encryption='none';}
 else if(proto=='ss'){need(type(p.cipher)=='string'&&type(p.password)=='string','CLASH_CIPHER_PASSWORD_REQUIRED');credential=p.cipher+':'+p.password;}
 else if(proto in ['socks5','http'])credential=p.username?(p.username+':'+(p.password||'')):'';
 else if(proto=='tuic'){need(p.uuid&&p.password,'CLASH_UUID_PASSWORD_REQUIRED');credential=p.uuid+':'+p.password;}
 else{need(type(p.password)=='string'&&length(p.password),'CLASH_PASSWORD_REQUIRED');credential=p.password;}
 if(p.servername||p.sni)params.sni=p.servername||p.sni;if(p['skip-cert-verify']!=null)params.allowInsecure=p['skip-cert-verify']?'true':'false';if(p['client-fingerprint']||p.fingerprint)params.fp=p['client-fingerprint']||p.fingerprint;if(p.alpn)params.alpn=type(p.alpn)=='array'?join(',',p.alpn):p.alpn;if(p.flow)params.flow=p.flow;
 if(p['packet-encoding'])params.packetEncoding=p['packet-encoding'];
 if(p['reality-opts']){let r=p['reality-opts'];for(let k in keys(r))need(k in ['public-key','short-id'],'UNMAPPED_CLASH_REALITY_FIELD');security='reality';params.pbk=r['public-key'];params.sid=r['short-id']||'';}
 if(transport=='ws'){let w=p['ws-opts']||{};for(let k in keys(w))need(k in ['path','headers'],'UNMAPPED_CLASH_WS_FIELD');params.path=w.path||'/';if(w.headers){for(let k in keys(w.headers))need(lc(k)=='host','CLASH_WS_HEADER_NOT_SUPPORTED');params.host=w.headers.Host||w.headers.host||'';}}
 else if(transport=='grpc'){let g=p['grpc-opts']||{};for(let k in keys(g))need(k in ['grpc-service-name','grpc-authority','multi-mode'],'UNMAPPED_CLASH_GRPC_FIELD');params.serviceName=g['grpc-service-name']||'';if(proto=='vmess')params.path=params.serviceName;if(g['grpc-authority'])params.authority=g['grpc-authority'];params.mode=g['multi-mode']?'multi':'gun';}
 else if(transport=='httpupgrade'){let h=p['http-upgrade-opts']||{};for(let k in keys(h))need(k in ['path','headers'],'UNMAPPED_CLASH_UPGRADE_FIELD');params.path=h.path||'/';params.host=h.headers?.Host||h.headers?.host||'';}
 else need(transport=='tcp','CLASH_TRANSPORT_NOT_SUPPORTED');
 if(p.obfs)params.obfs=p.obfs;if(p['obfs-password'])params['obfs-password']=p['obfs-password'];if(p['congestion-controller'])params.congestion_control=p['congestion-controller'];if(p['udp-relay-mode'])params.udp_relay_mode=p['udp-relay-mode'];if(p['disable-sni']!=null)params.disable_sni=p['disable-sni']?'true':'false';
 return {protocol:proto,name:substr(p.name||uc(proto),0,100),transport:transport,security:security,parameters:params,endpoint:{host:p.server,port:+p.port},credentials:credential};
};
