import {smart_enabled,wifi_interfaces} from '/usr/share/gale/lib/smart-policy.uc';
import {readfile,popen} from 'fs';
import {network_guard_rules} from '/usr/share/gale/lib/network-guard.uc';
function command(text){let p=popen(text,'r');if(!p)return {ok:false,text:''};let output=p.read('all')||'',code=p.close();return {ok:code==0,text:output};}
export function routing_state(bus){
 let settings=null;try{settings=json(readfile('/etc/gale/network-options.json')||'{}');}catch(e){}
 let guard_active=false,guard_issues=[];
 if(settings?.kill_switch){let g4=command('/usr/sbin/nft list chain inet fw4 forward 2>/dev/null'),gd=command('/usr/sbin/nft list chain inet fw4 input 2>/dev/null');let draft;try{draft=json(readfile('/etc/gale/routing-active.json')||readfile('/etc/gale/routing-test/draft.json')||'null');}catch(e){}let expected={forward:readfile('/usr/share/nftables.d/chain-pre/forward/40-gale-guard.nft')||'',input:readfile('/usr/share/nftables.d/chain-pre/input/40-gale-guard.nft')||''};guard_active=g4.ok&&gd.ok;for(let name in ['gale-killswitch-ipv4','gale-killswitch-ipv6','gale-blocked-devices'])if(index(expected.forward,name)>=0&&index(g4.text,name)<0)guard_active=false;for(let name in ['gale-killswitch-dns','gale-killswitch-dns6','gale-blocked-device-dns'])if(index(expected.input,name)>=0&&index(gd.text,name)<0)guard_active=false;if(!guard_active)push(guard_issues,'PERSISTENT_GUARD_MISSING');}
 let raw=readfile('/etc/gale/routing-test/armed'),marker=null;
 try{if(raw)marker=json(raw);}catch(e){return {requested:true,active:false,issues:['CORRUPT_ROUTING_MARKER']};}
 if(!marker||marker.simulation)return {requested:false,active:false,persistent_guard_active:guard_active,boot_reconnect:!!settings?.boot_connect,issues:guard_issues};
 let issues=guard_issues,table=command('/usr/sbin/nft list table inet gale_preview 2>/dev/null'),rules=command('ip -4 rule show 2>/dev/null'),route=command('ip -4 route show table 31001 2>/dev/null');
 if(!table.ok||index(table.text,'tproxy ip to 127.0.0.1:17893')<0||index(table.text,'redirect to :5354')<0)push(issues,'ROUTING_TABLE_INCOMPLETE');
 if(!match(rules.text,/31001:[^\n]*fwmark 0x6a1e0001[^\n]*lookup 31001/))push(issues,'POLICY_RULE_MISSING');
 if(!match(route.text,/local (default|0\.0\.0\.0\/0) dev lo/))push(issues,'LOCAL_ROUTE_MISSING');
 let active_policy;try{active_policy=json(readfile('/etc/gale/routing-active.json')||readfile('/etc/gale/routing-test/draft.json')||'{}');}catch(e){}
 if(active_policy&&smart_enabled(active_policy))for(let ap in wifi_interfaces(bus)){if(active_policy.wifi?.[ap.band]&&active_policy.wifi[ap.band]!='inherit'&&index(table.text,'band_'+ap.device)<0)push(issues,'WIFI_CLASSIFIER_MISSING');}
 if(settings?.ipv6_tunnel){let r6=command('ip -6 rule show 2>/dev/null'),t6=command('ip -6 route show table 31001 2>/dev/null');if(index(table.text,'tproxy ip6 to [::1]:17893')<0||index(r6.text,'lookup 31001')<0||!match(t6.text,/local (default|::\/0) dev lo/))push(issues,'IPV6_POLICY_INCOMPLETE');}
 let bridges=bus?.call('service','list',{name:'gale-route-bridges'})?.['gale-route-bridges']?.instances;
 if(!bridges?.dns?.running)push(issues,'DNS_BRIDGE_NOT_RUNNING');if(!bridges?.tcp?.running)push(issues,'TRANSPARENT_BRIDGE_NOT_RUNNING');
 let guard=bus?.call('service','list',{name:'gale-route-watch'})?.['gale-route-watch']?.instances?.guard;
 if(!guard?.running)push(issues,'NETWORK_GUARD_NOT_RUNNING');
 return {requested:true,persistent_guard_active:guard_active,active:length(issues)==0,scope:marker.session?'all_LAN_session':'temporary_trial',issues:issues,public_ipv6:settings?.ipv6_tunnel?'tunneled':'blocked',boot_reconnect:!!settings?.boot_connect,observed_at:time()};
};
