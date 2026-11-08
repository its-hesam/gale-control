import {readfile,writefile,rename,open} from 'fs';
import {test_udp_proxy} from '/usr/share/gale/lib/udp.uc';
import {lock_store,load_store,save_store} from '/usr/share/gale/lib/store.uc';
import {core_path} from '/usr/share/gale/lib/cores.uc';
import {event_add} from '/usr/share/gale/lib/events.uc';
let dir='/tmp/gale-connection',guard=open(dir+'/udp.lock','a',0o600);if(!guard||!guard.lock('xn'))exit(0);
let generation=readfile('/etc/gale/runtime/active');if(!generation)exit(1);let active=json(generation),kind=trim(readfile(dir+'/udp-kind')||'dns');
let dns='1.1.1.1';if(kind=='dns'){let profile=load_store().profiles[active.profile_id];if(profile?.model.protocol=='wireguard'){let primary=trim(split(profile.model.parameters.interface.DNS||'',',')[0]);if(primary in ['1.1.1.1','8.8.8.8','8.8.4.4'])dns=primary;}}
let result=test_udp_proxy(kind,17890,dns);
if(readfile('/etc/gale/runtime/active')!=generation){result.ok=false;result.error='CONNECTION_CHANGED_DURING_TEST';}
if(result.ok&&active.mode!='balanced')try{
 let lock=lock_store(),store=load_store(),p=store.profiles[active.profile_id];if(p){p.last_udp_test={...result,core_path:core_path(active.core)};save_store(store);}
}catch(e){result.persistence_error='UDP_RESULT_NOT_SAVED';}
writefile(dir+'/udp.new',sprintf('%J',{state:'complete',...result}));rename(dir+'/udp.new',dir+'/udp.json');
event_add('udp',result.ok?(kind=='ntp'?'NTP_PASSED':'DNS_PASSED'):result.error,active.profile_id);
