export const POLICY_MARKS={vpn:'0x6a1e0010',direct:'0x6a1e0011',block:'0x6a1e0012'};
export function validate_wifi_rules(value){
 if(value==null)return {};if(type(value)!='object')die('BAD_WIFI_POLICY');
 for(let band in keys(value))if(!(band in ['2g','5g'])||!(value[band] in ['inherit','vpn','direct','block']))die('BAD_WIFI_POLICY');return value;
};
export function wifi_interfaces(bus){
 let result=[],radios=bus.call('network.wireless','status',{})||{};
 for(let name in keys(radios)){let radio=radios[name],band=radio.config?.band;if(!(band in ['2g','5g']))continue;
  for(let ap in radio.interfaces||[]){if(ap.config?.mode!='ap'||index(ap.config?.network||[],'lan')<0||!match(ap.ifname||'',/^[a-zA-Z0-9_.-]{1,32}$/))continue;push(result,{band:band,device:ap.ifname,up:!!radio.up,ssid:substr(ap.config.ssid||'',0,64)});}
 }return result;
};
export function smart_enabled(draft){return !!draft.iran_direct||length(filter(values(draft.wifi||{}),a=>a!='inherit'))>0;};
export function smart_firewall(draft,udp,ipv6){
 validate_wifi_rules(draft.wifi);let nft='table inet gale_preview {\n',marks=POLICY_MARKS;
 for(let ap in draft.wifi_interfaces||[]){let action=draft.wifi?.[ap.band];if(!action||action=='inherit')continue;if(!match(ap.device||'',/^[a-zA-Z0-9_.-]{1,32}$/))die('BAD_WIFI_INTERFACE');
  nft+=' chain band_'+ap.device+' { type filter hook ingress device "'+ap.device+'" priority -500; policy accept; meta mark set '+marks[action]+'; }\n';
 }
 for(let family in [4,6]){let ips=draft.iran_direct?draft.iran_cidrs?.['v'+family]||[]:[];nft+=' set iran'+family+' { type ipv'+family+'_addr; flags interval; auto-merge;'+(length(ips)?' elements = { '+join(', ',ips)+' }':'')+' }\n';}
 nft+=' set local4 { type ipv4_addr; flags interval; elements = { 0.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 127.0.0.0/8, 169.254.0.0/16, 172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/4, 240.0.0.0/4 } }\n';
 nft+=' chain ingress { type filter hook prerouting priority -151; policy accept; iifname != "br-lan" return\n';
 for(let r in draft.rules||[]){let ip=r.ip||r.observed_ip;if(!match(ip||'',/^192\.168\.10\.[0-9]{1,3}$/)||!marks[r.action])die('BAD_POLICY_IP');nft+=' ip saddr '+ip+' meta mark set '+marks[r.action]+'\n';}
 // IP overrides are IPv4-only. Keep the previous explicit safety restriction.
 if(ipv6&&length(draft.rules||[]))die('IPV6_DEVICE_EXCEPTIONS_UNSUPPORTED');
 nft+=' meta mark != { '+join(', ',values(marks))+' } meta mark set '+marks[draft.default_action||'direct']+'\n';
 nft+=' meta mark '+marks.block+' meta l4proto { tcp, udp } th dport 53 drop\n';
 nft+=' ip daddr @local4 return\n ip6 daddr { fc00::/7, fe80::/10, ff00::/8 } return\n';
 nft+=' meta mark '+marks.block+' counter drop\n';
 if(draft.iran_direct)nft+=' meta mark '+marks.vpn+' ip daddr @iran4 meta mark set '+marks.direct+'\n meta mark '+marks.vpn+' ip6 daddr @iran6 meta mark set '+marks.direct+'\n';
 nft+=' meta mark '+marks.direct+' counter return\n';
 if(!ipv6)nft+=' meta nfproto ipv6 counter drop\n';
 nft+=' meta mark '+marks.vpn+' meta l4proto { tcp, udp } th dport 53 return\n';
 if(ipv6)nft+=' meta nfproto ipv6 meta mark '+marks.vpn+' meta l4proto { tcp, udp } counter tproxy ip6 to [::1]:17893 meta mark set 0x6a1e0001 accept\n';
 nft+=' meta nfproto ipv4 meta mark '+marks.vpn+' meta l4proto '+(udp?'{ tcp, udp }':'tcp')+' counter tproxy ip to 127.0.0.1:17893 meta mark set 0x6a1e0001 accept\n meta mark '+marks.vpn+' counter drop\n }\n';
 nft+=' chain dns { type nat hook prerouting priority dstnat - 1; policy accept; iifname != "br-lan" return\n meta mark '+marks.vpn+' meta l4proto { tcp, udp } th dport 53 counter meta mark set 0x6a1e0002 redirect to :5354\n }\n';
 nft+=' chain fail_closed { type filter hook forward priority -1; policy accept; meta mark { 0x6a1e0001, '+marks.vpn+', '+marks.block+' } counter drop; }\n';
 nft+=' chain protect_listeners { type filter hook input priority -1; policy accept; meta l4proto { tcp, udp } th dport { 5354, 17893 } meta mark != { 0x6a1e0001, 0x6a1e0002 } drop; }\n}\n';
 return {nft:nft,ready_to_apply:false,blockers:['Apply through the rollback-protected policy transaction'],mark:'0x6a1e0001',table:31001,priority:31001};
};
export function smart_guard(){
 let prefix='iifname "br-lan" meta mark != '+POLICY_MARKS.direct+' ';
 return {forward:prefix+'meta nfproto ipv4 ip daddr != { 0.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 127.0.0.0/8, 169.254.0.0/16, 172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/4, 240.0.0.0/4 } counter drop comment "gale-killswitch-ipv4"\n'+prefix+'meta nfproto ipv6 ip6 daddr != { fc00::/7, fe80::/10 } counter drop comment "gale-killswitch-ipv6"\n',input:prefix+'meta l4proto { tcp, udp } th dport 53 counter drop comment "gale-killswitch-dns"\n',protected_ipv4:true};
};
