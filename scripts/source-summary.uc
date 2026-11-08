import { load_store, lock_store } from '/usr/share/gale/lib/store.uc';
let lock=lock_store(),store=load_store(),sources=values(store.sources),total=0;
for(let source in sources)total+=length(source.profile_ids || []);
print({sources:length(sources),source_profile_total:total,unique_profiles:length(keys(store.profiles)),healthy:length(filter(sources,s=>s.last_success && !s.last_error)),errors:length(filter(sources,s=>s.last_error)),agents_configured:length(filter(sources,s=>length(s.user_agent || '')>0))});
