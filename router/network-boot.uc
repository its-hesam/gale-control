import {readfile,stat} from 'fs';
import {connect} from 'ubus';
if(stat('/etc/gale/ipv6-before/armed')&&!stat('/etc/gale/ipv6-before/committed'))system(['/usr/share/gale/ipv6-restore','--explicit'],15000);
let bus=connect(),launched=0;
for(;;){
 if(stat('/etc/gale/core-upgrade.pending')||stat('/etc/gale/recovery/pending.json')){system(['/bin/sleep','3'],4000);continue;}
 let settings;try{settings=json(readfile('/etc/gale/network-options.json')||'{}');}catch(e){exit(1);}
 if(!settings.boot_connect||!stat('/etc/gale/runtime/active'))exit(0);
 let status=bus.call('gale-connection','status',{});
 if(status?.routing?.active){system(['/bin/sleep','10'],11000);continue;}
 if(status?.running&&status.health?.ok&&time()-status.health.checked_at<60&&time()-launched>30){
  if(stat('/etc/gale/routing-test/armed'))system(['/usr/share/gale/routing-rollback','--preserve-ipv6'],15000);
  system(['/usr/share/gale/lan-launch'],3000);launched=time();
 }
 if(!status?.health?.ok&&!(status?.running&&(status?.active?.mode in ['best','failover']))&&time()-launched>60&&!(status?.operation?.state in ['queued','preparing','starting'])){let a=status?.active;if(a){bus.call('gale-connection','connect',{id:a.profile_id,mode:a.mode,pool_scope:a.pool_scope||'selected',pool:join(',',a.pool||[a.profile_id]),policy:sprintf('%J',a.policy||{}),auto_connect:true,lan:true,automatic:a.pool_scope!='enabled'});launched=time();}}
 system(['/bin/sleep','5'],6000);
}
