import {metadata} from '/usr/share/gale/lib/profiles.uc';
export function discovery_report(store,now){
 let candidates=[],protocols={},quarantined=0,duplicates=0,stale=0;
 for(let p in values(store.profiles)){
  let protocol=p.model.protocol;protocols[protocol]=(protocols[protocol]||0)+1;
  let memberships=length(filter(p.sources||[],s=>s!='manual'));if(memberships>1)duplicates+=memberships-1;
  if(p.native_status!='passed')quarantined++;
  let test=p.last_test,fresh=!!test&&now-test.tested_at>=0&&now-test.tested_at<=900;
  if(test&&!fresh)stale++;
  let successes=0,total=0;for(let h in p.test_history||[]){if(h.network_attempted!==false&&now-h.time>=0&&now-h.time<=86400){total++;if(h.ok)successes++;}}
  let recommendable=!p.source_retired&&p.native_status=='passed'&&fresh&&test.ok&&type(test.latency_ms) in ['int','double']&&test.latency_ms>=0;
  let trust='manual';for(let source in p.sources||[])if(store.sources[source]){trust=store.sources[source].public_untrusted?'untrusted':'owner_selected';if(trust=='untrusted')break;}
  for(let membership in values(p.provider_memberships||{}))if(membership.trust=='untrusted')trust='untrusted';
  let latency_score=recommendable?100/(100+test.latency_ms):0,reliability=(successes+1)/(total+2),score=recommendable?100*(0.6*latency_score+0.4*reliability):null;
  push(candidates,{...metadata(p),fresh:fresh,recommendable:recommendable,score:score,confidence:total>=5?'measured':total?'limited':'unknown',source_retired:!!p.source_retired,measured_successes:successes,measured_attempts:total,source_trust:trust});
 }
 candidates=sort(candidates,(a,b)=>(b.score||0)-(a.score||0));
 return {schema_version:1,observed_at:now,protocols:protocols,unique_profiles:length(candidates),cross_source_duplicates:duplicates,not_native_validated:quarantined,stale_tests:stale,candidates:candidates,automatic_activation:false};
};
