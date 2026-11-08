export function firewall_preview(draft,udp,ipv6){
 let direct=[],vpn=[],blocked=[];
 for(let rule in draft.rules||[]){let ip=rule.ip||rule.observed_ip;if(!match(ip||'',/^192\.168\.10\.[0-9]{1,3}$/))die('BAD_POLICY_IP');if(rule.action=='direct')push(direct,ip);else if(rule.action=='vpn')push(vpn,ip);else if(rule.action=='block')push(blocked,ip);else die('BAD_POLICY_ACTION');}
 let all=draft.default_action=='vpn',set=all?'192.168.10.0/24':join(', ',vpn);
 let rules='table inet gale_preview {\n';
 rules+=' set local4 { type ipv4_addr; flags interval; elements = { 0.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 127.0.0.0/8, 169.254.0.0/16, 172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/4, 240.0.0.0/4 } }\n';
 rules+=' set vpn4 { type ipv4_addr; flags interval;'+(length(set)?' elements = { '+set+' }':'')+' }\n';
 rules+=' chain ingress { type filter hook prerouting priority -151; policy accept;\n iifname != "br-lan" return\n';
 if(length(direct))rules+=' ip saddr { '+join(', ',direct)+' } return\n';
 if(length(blocked))rules+=' ip saddr { '+join(', ',blocked)+' } meta l4proto { tcp, udp } th dport 53 drop\n ip saddr { '+join(', ',blocked)+' } ip daddr != @local4 drop\n';
 // Timed IPv4-only trial: keep local IPv6 administration and NDP, block public IPv6.
 if(ipv6){if(!all||length(direct)||length(blocked))die('IPV6_REQUIRES_ALL_LAN_VPN');rules+=' meta nfproto ipv6 meta l4proto { tcp, udp } th dport 53 return\n ip6 daddr { fc00::/7, fe80::/10, ff00::/8 } return\n meta nfproto ipv6 meta l4proto { tcp, udp } counter tproxy ip6 to [::1]:17893 meta mark set 0x6a1e0001 accept\n meta nfproto ipv6 counter drop\n';}else if(all||length(vpn)||length(blocked)){rules+=' meta nfproto ipv6 meta l4proto { tcp, udp } th dport 53 counter drop\n ip6 daddr { fc00::/7, fe80::/10 } return\n meta l4proto ipv6-icmp icmpv6 type { nd-router-solicit, nd-router-advert, nd-neighbor-solicit, nd-neighbor-advert } return\n meta nfproto ipv6 counter drop\n';}
 rules+=' meta nfproto ipv4 ip saddr @vpn4 meta l4proto { tcp, udp } th dport 53 return\n';
 rules+=' ip daddr @local4 return\n';
 rules+=udp?' ip saddr @vpn4 meta l4proto udp counter tproxy ip to 127.0.0.1:17893 meta mark set 0x6a1e0001 accept\n':' ip saddr @vpn4 meta l4proto udp drop\n';
 rules+=' ip saddr @vpn4 meta l4proto tcp counter tproxy ip to 127.0.0.1:17893 meta mark set 0x6a1e0001 accept\n }\n';
 rules=replace(rules,'accept\n }\n','accept\n ip saddr @vpn4 counter drop\n }\n');
 rules+=' chain dns { type nat hook prerouting priority dstnat - 1; policy accept;\n iifname != "br-lan" return\n';
 if(length(direct))rules+=' ip saddr { '+join(', ',direct)+' } return\n';
 if(ipv6)rules+=' meta nfproto ipv6 meta l4proto { tcp, udp } th dport 53 counter meta mark set 0x6a1e0002 redirect to :5354\n';
 rules+=' ip saddr @vpn4 meta l4proto { tcp, udp } th dport 53 counter meta mark set 0x6a1e0002 redirect to :5354\n }\n';
 rules+=' chain fail_closed { type filter hook forward priority -1; policy accept; meta mark 0x6a1e0001 counter drop; }\n';
 rules+=' chain protect_listeners { type filter hook input priority -1; policy accept;\n meta l4proto { tcp, udp } th dport { 5354, 17893 } meta mark != { 0x6a1e0001, 0x6a1e0002 } drop\n }\n}\n';
 return {nft:rules,mark:'0x6a1e0001',table:31001,priority:31001,proposed_commands:['ip -4 route add local 0.0.0.0/0 dev lo table 31001','ip -4 rule add priority 31001 fwmark 0x6a1e0001/0xffffffff lookup 31001'],rollback_commands:['nft delete table inet gale_preview','ip -4 rule del priority 31001 fwmark 0x6a1e0001/0xffffffff lookup 31001','ip -4 route del local 0.0.0.0/0 dev lo table 31001'],ready_to_apply:false,blockers:['Full IPv6 forwarding and leakage tests incomplete; trial blocks public IPv6',udp?'IPv4 UDP LAN trial requires separate measured results':'TCP-only trial blocks public UDP','Long-running multi-device DNS leakage tests incomplete','Watchdog expiration during real interception not yet exercised','Per-device exception behavior requires real network tests','Current generated policy still requires confirmation before applying']};
};
