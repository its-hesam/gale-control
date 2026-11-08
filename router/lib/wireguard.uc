import {managed_feature_core} from '/usr/share/gale/lib/cores.uc';
function key(value){return type(value)=='string'&&!!match(value,/^[A-Za-z0-9+/]{43}=$/)&&length(b64dec(value)||'')==32;}
export function wireguard_endpoint(value){let hp=type(value)=='string'?(match(value,/^\[([0-9a-fA-F:]+)\]:([0-9]+)$/)||match(value,/^([A-Za-z0-9][A-Za-z0-9.-]*):([0-9]+)$/)):null;if(!hp||+hp[2]<1||+hp[2]>65535)die('WIREGUARD_ENDPOINT_REQUIRED');return {host:lc(hp[1]),port:+hp[2]};};
export function parse_wireguard(raw){
 let iface={},peers=[],section=null;
 for(let input in split(raw,/\r?\n/)){
  let line=trim(input),comment=index(line,'#');if(comment>=0)line=trim(substr(line,0,comment));if(!length(line)||substr(line,0,1)==';')continue;
  if(line=='[Interface]'){if(section!=null)die('DUPLICATE_WIREGUARD_INTERFACE');section=iface;continue;}
  if(line=='[Peer]'){let peer={};push(peers,peer);section=peer;continue;}
  let pair=match(line,/^([A-Za-z][A-Za-z0-9]*)\s*=\s*(.*)$/);if(!pair||!section)die('BAD_WIREGUARD_LINE');
  let name=pair[1],value=trim(pair[2]);if(name in ['PreUp','PostUp','PreDown','PostDown','SaveConfig'])die('UNSAFE_WIREGUARD_DIRECTIVE');
  if(exists(section,name)){if(name in ['Address','DNS','AllowedIPs'])section[name]+=','+value;else die('DUPLICATE_WIREGUARD_FIELD');}else section[name]=value;
 }
 if(!key(iface.PrivateKey)||!length(peers))die('BAD_WIREGUARD');
 for(let peer in peers)if(!key(peer.PublicKey)||(peer.PresharedKey&&!key(peer.PresharedKey)))die('BAD_WIREGUARD_KEY');
 if(length(peers)>16)die('WIREGUARD_PEER_LIMIT');let seen={};for(let p in peers){wireguard_endpoint(p.Endpoint);if(seen[p.PublicKey])die('DUPLICATE_WIREGUARD_PEER');seen[p.PublicKey]=true;}let first=wireguard_endpoint(peers[0].Endpoint);
 return {protocol:'wireguard',name:'WireGuard',transport:'udp',security:'wireguard',endpoint:first,credentials:{private_key:iface.PrivateKey},parameters:{interface:iface,peers:peers}};
};
export function wireguard_config(model){
 let iface=model.parameters.interface,peers=model.parameters.peers;
 if(!length(peers)||length(peers)>16)die('WIREGUARD_PEER_LIMIT');
 for(let name in keys(iface))if(!(name in ['PrivateKey','Address','DNS','MTU','Table','ListenPort']))die('UNMAPPED_WIREGUARD_INTERFACE_FIELD');
 if(iface.ListenPort&&iface.ListenPort!='0')die('WIREGUARD_FIXED_LISTEN_PORT_NOT_IMPLEMENTED');
 if(iface.Table&&!(iface.Table in ['off','auto']))die('WIREGUARD_ROUTING_TABLE_NOT_IMPLEMENTED');
 if(!iface.Address)die('WIREGUARD_ADDRESS_REQUIRED');
 let converted=[],routes={};for(let input in peers){let remote=wireguard_endpoint(input.Endpoint);for(let name in keys(input))if(!(name in ['PublicKey','PresharedKey','Endpoint','AllowedIPs','PersistentKeepalive','Reserved']))die('UNMAPPED_WIREGUARD_PEER_FIELD');
 if(!input.AllowedIPs)die('WIREGUARD_ALLOWED_IPS_REQUIRED');
 let peer={address:remote.host,port:remote.port,public_key:input.PublicKey,allowed_ips:map(split(input.AllowedIPs,','),s=>trim(s))};
 if(input.PresharedKey)peer.pre_shared_key=input.PresharedKey;
 if(input.PersistentKeepalive){if(!match(input.PersistentKeepalive,/^[0-9]+$/)||+input.PersistentKeepalive>65535)die('BAD_WIREGUARD_KEEPALIVE');peer.persistent_keepalive_interval=+input.PersistentKeepalive;}
 if(input.Reserved){let parts=map(split(input.Reserved,','),s=>trim(s));if(length(parts)!=3)die('BAD_WIREGUARD_RESERVED');for(let n in parts)if(!match(n,/^[0-9]+$/)||+n>255)die('BAD_WIREGUARD_RESERVED');peer.reserved=map(parts,n=>+n);}
 for(let cidr in peer.allowed_ips){if(routes[cidr])die('WIREGUARD_OVERLAPPING_PEER_PREFIX');routes[cidr]=true;}push(converted,peer);}
 let endpoint={type:'wireguard',tag:'vpn',system:false,address:map(split(iface.Address,','),s=>trim(s)),private_key:model.credentials.private_key,peers:converted};
 if(iface.MTU){if(!match(iface.MTU,/^[0-9]+$/)||+iface.MTU<576||+iface.MTU>9000)die('BAD_WIREGUARD_MTU');endpoint.mtu=+iface.MTU;}
 let resolvers=iface.DNS?map(split(iface.DNS,','),s=>trim(s)):['1.1.1.1'];
 if(length(resolvers)>8)die('WIREGUARD_DNS_LIMIT');
 for(let dns in resolvers)if(!match(dns,/^[0-9a-fA-F:.]+$/))die('WIREGUARD_DNS_IP_REQUIRED');
 let servers=[];for(let i,dns in resolvers)push(servers,{type:'udp',tag:i?'wg-dns-'+i:'wg-dns',server:dns,detour:'vpn'});
 let rules=[];for(let i=0;i<length(servers)-1;i++){push(rules,{action:'evaluate',server:servers[i].tag,tag:'resolver-'+i,timeout:'2s'});for(let code in ['NOERROR','NXDOMAIN'])push(rules,{match_response:'resolver-'+i,response_rcode:code,action:'respond'});}if(length(servers)>1)push(rules,{action:'route',server:servers[length(servers)-1].tag,timeout:'2s'});
 return {core:'sing-box',...(length(servers)>1?managed_feature_core('sing-box','1.14.4','WireGuard_DNS_failover'):{}),dns_policy:length(servers)>1?'ordered_timeout_failover':'first_configured_resolver',configured_dns_count:length(servers),config:{log:{disabled:true},dns:{servers:servers,rules:rules,final:servers[length(servers)-1].tag,strategy:'prefer_ipv4'},endpoints:[endpoint],outbounds:[],inbounds:[],route:{final:'vpn',default_domain_resolver:'wg-dns'}}};
};
