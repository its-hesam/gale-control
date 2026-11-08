import {validate_device_rules} from '/usr/share/gale/lib/network-plan.uc';
let devices=[{mac:'02:00:00:00:00:01',ip:'192.168.10.20'}];
let rules=validate_device_rules([{mac:'02:00:00:00:00:01',action:'vpn'}],devices);assert(rules[0].observed_ip=='192.168.10.20','lease binding lost');
for(let input in [[{mac:'02:00:00:00:00:02',action:'vpn'}],[{mac:'02:00:00:00:00:01',action:'execute'}],[{mac:'02:00:00:00:00:01',action:'vpn',command:'bad'}],[{mac:'02:00:00:00:00:01',action:'vpn'},{mac:'02:00:00:00:00:01',action:'direct'}]]){let rejected=false;try{validate_device_rules(input,devices);}catch(e){rejected=true;}assert(rejected,'unsafe policy accepted');}
let ip_rule=validate_device_rules([{ip:'192.168.10.30',action:'direct'}],devices);assert(ip_rule[0].ip==='192.168.10.30'&&ip_rule[0].observed_mac==null,'static IP rule rejected');
for(let ip in ['192.168.10.1','192.168.10.255','192.168.100.20']){let denied=false;try{validate_device_rules([{ip:ip,action:'vpn'}],devices);}catch(e){denied=true;}assert(denied,'router, broadcast or non-LAN IP accepted');}
print({passed:9,scope:'device_policy_drafts_only'});
