export function dns_bridge_config(){return {log:{disabled:true},dns:{servers:[{type:'https',tag:'remote-dns',server:'1.1.1.1',server_port:443,path:'/dns-query',detour:'vpn-proxy'}],final:'remote-dns'},inbounds:[{type:'direct',tag:'dns-in',listen:'127.0.0.1',listen_port:5353}],outbounds:[{type:'socks',tag:'vpn-proxy',server:'127.0.0.1',server_port:17890,version:'5'}],route:{rules:[{inbound:['dns-in'],action:'hijack-dns'}],final:'vpn-proxy'}};};
export function transparent_bridge_config(udp){return {log:{loglevel:'none'},inbounds:[{tag:'transparent',listen:'127.0.0.1',port:17893,protocol:'dokodemo-door',settings:{network:udp?'tcp,udp':'tcp',followRedirect:true},streamSettings:{sockopt:{tproxy:'tproxy'}}}],outbounds:[{tag:'vpn-proxy',protocol:'socks',settings:{servers:[{address:'127.0.0.1',port:17890}]}}]};};
export function validate_device_rules(rules,devices){
 if(type(rules)!='array'||length(rules)>32)die('DEVICE_RULE_LIMIT');let seen={},result=[];
 for(let rule in rules){
  if(type(rule)!='object')die('BAD_DEVICE_RULE');for(let key in keys(rule))if(!(key in ['mac','ip','action']))die('UNKNOWN_POLICY_FIELD');
  if(!(rule.action in ['vpn','direct','block']))die('BAD_DEVICE_RULE');
  if(rule.ip!=null){
   if(type(rule.ip)!='string'||!match(rule.ip,/^192\.168\.10\.([1-9][0-9]{0,2})$/))die('BAD_DEVICE_IP');
   let host=+split(rule.ip,'.')[3];if(host<=1||host>=255)die('ROUTER_OR_RESERVED_IP');if(seen[rule.ip])die('DUPLICATE_DEVICE_RULE');seen[rule.ip]=true;
   let matches=filter(devices,d=>d.ip==rule.ip);push(result,{ip:rule.ip,action:rule.action,observed_mac:matches[0]?.mac||null});continue;
  }
  if(type(rule.mac)!='string'||!match(rule.mac,/^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$/))die('BAD_DEVICE_RULE');
  let mac=lc(rule.mac);if(seen[mac])die('DUPLICATE_DEVICE_RULE');seen[mac]=true;
  let matches=filter(devices,d=>lc(d.mac)==mac);if(!length(matches))die('DEVICE_NOT_IN_CURRENT_LEASES');
  push(result,{mac:mac,action:rule.action,observed_ip:matches[0].ip});
 }
 return result;
};
