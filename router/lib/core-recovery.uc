import {readfile,writefile,rename,unlink,chmod} from 'fs';import {lock_store,load_store,save_store} from '/usr/share/gale/lib/store.uc';
export function recover_core(snapshot){
 if(snapshot.registry==null)unlink('/etc/gale/cores.json');else{writefile('/etc/gale/cores.recover',snapshot.registry);chmod('/etc/gale/cores.recover',0o600);if(!rename('/etc/gale/cores.recover','/etc/gale/cores.json'))die('CORE_RECOVERY_COMMIT_FAILED');}
 for(let f in ['config.json','binary','active','sidecars','sidecar-1.json','sidecar-2.json','binary-1','binary-2']){if(snapshot.runtime[f]==null)unlink('/etc/gale/runtime/'+f);else{writefile('/etc/gale/runtime/'+f,snapshot.runtime[f]);chmod('/etc/gale/runtime/'+f,0o600);}}
 let lock=lock_store(),store=load_store();for(let id in keys(snapshot.metadata)){let p=store.profiles[id];if(!p)continue;let m=snapshot.metadata[id];for(let field in ['native_status','native_core','native_core_version','native_error','native_checked_at','enabled','last_test','last_performance','last_udp_test','handshake_status']){if(exists(m,field))p[field]=m[field];else delete p[field];}}save_store(store);unlink('/etc/gale/runtime/pending');
};
