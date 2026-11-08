import {readfile,writefile,rename,stat,open} from 'fs';
import {connect} from 'ubus';
let root='/tmp/gale-connection',guard=open(root+'/lan.lock','a',0o600);if(!guard||!guard.lock('xn'))exit(0);
function save(state,error){writefile(root+'/lan.new',sprintf('%J',{state:state,error:error||null,updated_at:time()}));rename(root+'/lan.new',root+'/lan.json');}
let control=open(root+'/control.lock','a',0o600);if(!control||!control.lock('xn')){save('failed','CONNECTION_BUSY');exit(0);}
try{
 save('verifying');let bus=connect(),healthy=false;
 for(let i=0;i<30;i++){let s=bus.call('gale-connection','status',{});if(!s.active)die('CONNECTION_STOPPED');if(s.running&&s.health?.ok&&time()-s.health.checked_at<60){healthy=true;break;}system(['/bin/sleep','1'],2000);}
 if(!healthy)die('LAN_REQUIRES_HEALTHY_PROXY');
 // The helper has its own lock and records a result for this active generation.
 let udp_ok=false;
 for(let kind in ['dns','ntp']){
  writefile(root+'/udp-kind',kind);
  if(system(['/usr/bin/timeout','12','/usr/bin/ucode','/usr/share/gale/connection-udp.uc'],14000)==0){let udp=json(readfile(root+'/udp.json')||'{}');if(udp.ok&&udp.method in ['SOCKS5_UDP_DNS','SOCKS5_UDP_NTP']&&time()-udp.tested_at<30){udp_ok=true;break;}}
 }
 if(!udp_ok)die('LAN_UDP_CHECK_FAILED');
 let existing=stat('/etc/gale/routing-test/armed');
 if(!existing){
 if(system(['/usr/bin/ucode','/usr/share/gale/routing-prepare.uc','session'],15000)!=0)die('LAN_PREPARATION_FAILED');
 if(system(['/usr/share/gale/routing-apply','--all-lan-session'],20000)!=0)die('LAN_APPLY_FAILED');
 }
 let current=json(readfile('/etc/gale/runtime/active')||'{}');
 if(current.auto_connect&&!stat('/etc/gale/network-options.json')){if(system(['/usr/share/gale/network-guard-install','--owner-approved-persistent-guard'],20000)!=0)die('PERSISTENT_GUARD_INSTALL_FAILED');}
 save('active');
}catch(e){save('failed',match(e.message||'',/^[A-Z0-9_]+$/)?e.message:'LAN_START_FAILED');}
