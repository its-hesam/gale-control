import { load_store, lock_store } from '/usr/share/gale/lib/store.uc';
let lock=lock_store(),store=load_store(),groups={},parameters={};
for(let p in values(store.profiles)){
 let group=p.model.protocol+'/'+p.model.transport+'/'+p.model.security;groups[group]=(groups[group]||0)+1;
 for(let key in keys(p.model.parameters))parameters[key]=(parameters[key]||0)+1;
}
print({total:length(keys(store.profiles)),groups:groups,parameter_keys:parameters});
