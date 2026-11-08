import {connection_request,switch_candidate,initial_candidate,connection_policy} from '/usr/share/gale/lib/selection.uc';
let a='',b='';for(let i=0;i<64;i++){a+='a';b+='b';}
let store={profiles:{}};store.profiles[a]={native_status:'passed'};store.profiles[b]={native_status:'passed'};
let req=connection_request({id:a,mode:'failover',pool:a+','+b},store);assert(length(req.pool)==2,'pool lost');
let active={profile_id:a,pool:[a,b],mode:'failover',started_at:0},health={ok:false,consecutive_failures:3,latency_ms:null},m={};m[b]={ok:true,latency_ms:100,tested_at:200};
assert(switch_candidate(active,health,m,220)==b,'confirmed failure did not switch');
assert(switch_candidate(active,health,m,100)==null,'hold time ignored');
assert(switch_candidate(active,health,m,1200)==null,'stale measurement accepted');
health={ok:true,consecutive_failures:0,latency_ms:300};assert(switch_candidate(active,health,m,220)==null,'failover acted as best');
active.mode='best';assert(switch_candidate(active,health,m,220)==b,'best improvement ignored');
health.latency_ms=110;assert(switch_candidate(active,health,m,220)==null,'small improvement switched');
active.mode='manual';health.consecutive_failures=10;assert(switch_candidate(active,health,m,220)==null,'manual switched');
let rejected=false;try{connection_request({id:a,mode:'failover',pool:a},store);}catch(e){rejected=true;}assert(rejected,'missing backup accepted');
store.profiles[a].last_test={ok:true,tested_at:200,latency_ms:500};store.profiles[b].last_test={ok:true,tested_at:200,latency_ms:100};
assert(initial_candidate({mode:'best',id:a,pool:[a,b]},store,220)==b,'initial best selection ignored measurements');
assert(initial_candidate({mode:'best',id:a,pool:[a,b],automatic:true},store,220)==a,'automatic target overridden by cached measurement');
assert(connection_policy({failures:5}).failures==5,'policy value lost');
for(let invalid in [{health_interval:0},{probe_interval:1},{failures:1},{min_hold:1},{improvement_percent:100},{unknown:1}]){let denied=false;try{connection_policy(invalid);}catch(e){denied=true;}assert(denied,'unsafe policy accepted');}
print({passed:18,scope:'connection_policy_decisions'});
