import {readfile,writefile,rename,stat,mkdtemp,unlink,rmdir} from 'fs';
import {open} from 'fs';
import {connect} from 'ubus';
import {load_store} from '/usr/share/gale/lib/store.uc';
import {probe_profile} from '/usr/share/gale/lib/benchmark.uc';
import {switch_candidate,connection_policy,automatic_pool} from '/usr/share/gale/lib/selection.uc';
import {event_add} from '/usr/share/gale/lib/events.uc';
let dir='/tmp/gale-connection';
let failures=0,measurements={},cursor=0,last_probe=0,previous_ok=null;
// Give supervised listeners time to bind before the first health request.
system(['/bin/sleep','2'],3000);
while(stat('/etc/gale/runtime/active')){
 let generation=readfile('/etc/gale/runtime/active'),temp=mkdtemp('/tmp/gale-health-XXXXXX');if(!temp)exit(1);
 let code=system(['/usr/share/gale/active-probe',temp],12000),r;try{r=json(readfile(temp+'/result.json')||'{}');}catch(e){r={};}
 unlink(temp+'/result.json');rmdir(temp);
 if(readfile('/etc/gale/runtime/active')!=generation)exit(0);
 let ok=code==0&&r.http_code==204;failures=ok?0:failures+1;
 let active=json(generation);
 let policy=connection_policy(active.policy);
 if(ok!==previous_ok){event_add('health',ok?'HTTPS_PASSED':'HTTPS_FAILED',active.profile_id);previous_ok=ok;}
 let health={profile_id:active.profile_id,checked_at:time(),ok:ok,latency_ms:ok?r.time_total*1000:null,consecutive_failures:failures,scope:'local_proxy_https',network_routing_active:false};
 writefile(dir+'/health.new',sprintf('%J',health));rename(dir+'/health.new',dir+'/health.json');
 if(active.mode in ['best','failover']){
  // Candidate measurements remain in RAM: repeated health checks must not rewrite flash catalogs.
  if(active.pool_scope=='enabled'){let catalog=load_store();active.pool=automatic_pool(catalog,active.profile_id,time());active.excluded_from_pool=!catalog.profiles[active.profile_id]?.enabled;}
  let pool=filter(active.pool||[],id=>id!=active.profile_id);
  if(length(pool)&&time()-last_probe>=policy.probe_interval){
   let probe_guard=open('/etc/gale/probe.lock','a',0o600);
   if(probe_guard&&probe_guard.lock('xn')){
    let store=load_store(),id=pool[cursor++%length(pool)],p=store.profiles[id];
    if(p?.native_status=='passed')try{measurements[id]=probe_profile(p,store.security);}catch(e){}
    probe_guard.close();last_probe=time();
    writefile(dir+'/candidates.new',sprintf('%J',measurements));rename(dir+'/candidates.new',dir+'/candidates.json');
   }
  }
  let next=switch_candidate(active,health,measurements,time());
  if(next&&readfile('/etc/gale/runtime/active')==generation){
   let bus=connect(),result=bus?.call('gale-connection','connect',{id:next,mode:active.mode,pool_scope:active.pool_scope||'selected',pool:join(',',active.pool),auto_connect:!!active.auto_connect,automatic:true,policy:sprintf('%J',policy)});
   if(result?.state=='queued'){event_add('automatic_switch',active.mode,next);exit(0);}
  }
 }
 system(['/bin/sleep',''+policy.health_interval],(policy.health_interval+1)*1000);
}
