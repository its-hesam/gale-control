export function automatic_pool(store,primary,now){let items=filter(values(store.profiles),p=>p.enabled&&p.native_status=='passed'&&!p.source_retired&&p.model.protocol!='openvpn');items=sort(items,(a,b)=>{let x=a.last_test,y=b.last_test,xf=x?.ok&&now-x.tested_at>=0&&now-x.tested_at<=900,yf=y?.ok&&now-y.tested_at>=0&&now-y.tested_at<=900;if(xf!=yf)return xf?-1:1;if(xf&&yf)return x.latency_ms-y.latency_ms;return (x?.tested_at||0)-(y?.tested_at||0);});let ids=map(slice(items,0,4),p=>p.id);if(primary&&store.profiles[primary]?.native_status=='passed'&&!(primary in ids)){if(length(ids)>=4)pop(ids);unshift(ids,primary);}return ids;};
export function connection_policy(value){
 let defaults={health_interval:30,probe_interval:60,min_hold:120,failures:3,improvement_percent:20},ranges={health_interval:[5,120],probe_interval:[30,600],min_hold:[30,900],failures:[2,10],improvement_percent:[1,90]};
 if(value==null)return defaults;if(type(value)!='object')die('BAD_CONNECTION_POLICY');
 for(let key in keys(value)){if(!exists(defaults,key)||type(value[key])!='int'||value[key]<ranges[key][0]||value[key]>ranges[key][1])die('BAD_CONNECTION_POLICY');defaults[key]=value[key];}return defaults;
};
export function connection_request(req,store){
 let mode=req.mode||'manual',scope=req.pool_scope||'selected';if(!(scope in ['selected','enabled'])||(scope=='enabled'&&!(mode in ['best','failover'])))die('BAD_POOL_SCOPE');
 if(scope=='enabled'){let chosen=automatic_pool(store,req.automatic?req.id:null,time());if(!length(chosen))die('NO_APPROVED_AUTO_CANDIDATES');if(req.automatic&&(!store.profiles[req.id]?.enabled||store.profiles[req.id]?.native_status!='passed'))die('AUTO_CANDIDATE_DISABLED');req={...req,id:req.automatic?req.id:chosen[0],pool:join(',',chosen)};}if(!(mode in ['manual','best','failover','balanced']))die('CONNECTION_MODE_NOT_IMPLEMENTED');
 if(type(req.id)!='string'||!match(req.id,/^[0-9a-f]{64}$/))die('BAD_PROFILE');
 let pool=req.pool ? split(req.pool,','):[req.id];
 if(length(pool)<1||length(pool)>4)die('POOL_LIMIT');
 let seen={};for(let id in pool){if(!match(id,/^[0-9a-f]{64}$/)||seen[id])die('BAD_POOL');seen[id]=true;if(store.profiles[id]?.native_status!='passed')die('NATIVE_VALIDATION_REQUIRED');}
 if(!seen[req.id])die('PRIMARY_NOT_IN_POOL');
 if(scope=='selected'&&mode!='manual'&&length(pool)<2)die('BACKUP_PROFILE_REQUIRED');
 if(mode=='balanced'&&length(pool)!=2)die('BALANCED_POOL_REQUIRES_TWO');
 let policy=null;if(req.policy!=null)try{policy=json(req.policy);}catch(e){die('BAD_CONNECTION_POLICY');}
 return {id:req.id,mode:mode,pool_scope:scope,pool:pool,auto_connect:!!req.auto_connect,automatic:req.automatic===true,policy:connection_policy(policy)};
};
export function initial_candidate(req,store,now){
 if(req.mode!='best'||req.automatic)return req.id;let ranked=[];
 for(let id in req.pool){let p=store.profiles[id],m=p?.last_test;if(p?.native_status=='passed'&&m?.ok&&type(m.latency_ms) in ['int','double']&&m.latency_ms>=0&&now-m.tested_at>=0&&now-m.tested_at<=900)push(ranked,{id:id,latency:m.latency_ms});}
 ranked=sort(ranked,(a,b)=>a.latency-b.latency);return ranked[0]?.id||req.id;
};
export function switch_candidate(active,health,measurements,now){
 let policy=connection_policy(active.policy);
 if(!(active.mode in ['best','failover'])||now-active.started_at<policy.min_hold)return null;
 let ranked=[];
 for(let id in active.pool||[]){let m=measurements[id];if(id!=active.profile_id&&m?.ok&&type(m.latency_ms) in ['int','double']&&m.latency_ms>=0&&now-m.tested_at>=0&&now-m.tested_at<=900)push(ranked,{id:id,latency:m.latency_ms});}
 ranked=sort(ranked,(a,b)=>a.latency-b.latency);let best=ranked[0];if(!best)return null;
 if(active.pool_scope=='enabled'&&active.excluded_from_pool)return best.id;
 if(health.consecutive_failures>=policy.failures)return best.id;
 if(active.mode=='best'&&health.ok&&health.latency_ms>0&&best.latency*100<health.latency_ms*(100-policy.improvement_percent))return best.id;
 return null;
};
