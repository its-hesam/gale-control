import {smart_enabled,smart_guard} from '/usr/share/gale/lib/smart-policy.uc';
export function network_guard_rules(draft){
 if(draft&&smart_enabled(draft))return smart_guard();
 draft=draft||{default_action:'vpn',rules:[]};let all=draft.default_action=='vpn',vpn=[],direct=[],blocked=[];
 for(let r in draft.rules||[]){let ip=r.ip||r.observed_ip;if(!match(ip||'',/^192\.168\.10\.([1-9][0-9]{0,2})$/)||+split(ip,'.')[3]<=1||+split(ip,'.')[3]>=255)die('BAD_POLICY_IP');if(r.action=='vpn')push(vpn,ip);else if(r.action=='direct')push(direct,ip);else if(r.action=='block')push(blocked,ip);else die('BAD_POLICY_ACTION');}
 let local4='{ 0.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 127.0.0.0/8, 169.254.0.0/16, 172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/4, 240.0.0.0/4 }';
 let protected4=all?'ip saddr 192.168.10.0/24':length(vpn)?'ip saddr { '+join(', ',vpn)+' }':null;
 if(protected4&&all&&length(direct))protected4+=' ip saddr != { '+join(', ',direct)+' }';
 let forward='# Gale managed network guard\n',input='# Gale managed DNS guard\n';
 if(protected4){forward+='iifname "br-lan" '+protected4+' ip daddr != '+local4+' counter drop comment "gale-killswitch-ipv4"\n';input+='iifname "br-lan" '+protected4+' meta l4proto { tcp, udp } th dport 53 counter drop comment "gale-killswitch-dns"\n';}
 if(length(blocked)){forward+='iifname "br-lan" ip saddr { '+join(', ',blocked)+' } ip daddr != '+local4+' counter drop comment "gale-blocked-devices"\n';input+='iifname "br-lan" ip saddr { '+join(', ',blocked)+' } meta l4proto { tcp, udp } th dport 53 counter drop comment "gale-blocked-device-dns"\n';}
 if(protected4||length(blocked)){forward+='iifname "br-lan" meta nfproto ipv6 ip6 daddr != { fc00::/7, fe80::/10 } counter drop comment "gale-killswitch-ipv6"\n';input+='iifname "br-lan" meta nfproto ipv6 meta l4proto { tcp, udp } th dport 53 counter drop comment "gale-killswitch-dns6"\n';}
 return {forward:forward,input:input,protected_ipv4:!!protected4};
};
