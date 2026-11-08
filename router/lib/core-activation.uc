import {readfile,writefile,rename,chmod,open,stat} from 'fs';import {core_state} from '/usr/share/gale/lib/cores.uc';import {lock_store,load_store,save_store} from '/usr/share/gale/lib/store.uc';
export function activate_core(id,target){
 if(!(id in ['xray','sing-box'])||(target!=null&&!match(target,/^[0-9]+\.[0-9]+\.[0-9]+$/)))die('BAD_CORE_VERSION');
 let guard=open('/etc/gale/core-manager.lock','a',0o600);if(!guard||!guard.lock('xn'))die('CORE_MANAGER_BUSY');let probe=open('/etc/gale/probe.lock','a',0o600);if(!probe||!probe.lock('xn'))die('PROBE_BUSY');if(stat('/etc/gale/runtime/active'))die('DISCONNECT_BEFORE_CORE_CHANGE');let state=core_state();
 let path=target?'/usr/share/gale/managed/'+id+'/'+target+'/core':'/usr/bin/'+id;
 if(target){let raw=readfile('/usr/share/gale/managed/'+id+'/'+target+'/receipt.json');if(!raw)die('CORE_NOT_STAGED');let receipt=json(raw);if(receipt.id!=id||receipt.version!=target||!match(receipt.binary_sha256||'',/^[0-9a-f]{64}$/))die('BAD_CORE_RECEIPT');
  let dir='/usr/share/gale/managed/'+id+'/'+target;
  if(system(['/usr/share/gale/verify-core',dir,receipt.binary_sha256],5000)!=0)die('CORE_HASH_MISMATCH');
 }
 // Capture output privately: native version/check commands can emit text before JSON.
 let output='/tmp/gale-core-check';
 let code=system(['/usr/share/gale/capture',output,path,id=='xray'?'run':'check',...(id=='xray'?['-test']:[]),'-c','/usr/share/gale/selftests/'+(id=='xray'?'xray-direct.json':'sing-box-direct.json')],5000);
 if(code!=0)die('CORE_HEALTH_CHECK_FAILED');
 let lock=lock_store(),store=load_store();
 // Invalidate measurements before selecting a different executable (fail closed).
 for(let p in values(store.profiles)){p.native_status='not_checked';p.enabled=false;p.native_error=null;delete p.last_performance;delete p.last_udp_test;delete p.last_test;p.handshake_status='not_tested';}save_store(store);
 state[id]={current:target,previous:state[id]?.current || null,activated_at:time()};
 if(!writefile('/etc/gale/cores.new',sprintf('%J',state)))die('CORE_COMMIT_FAILED');chmod('/etc/gale/cores.new',0o600);if(!rename('/etc/gale/cores.new','/etc/gale/cores.json'))die('CORE_COMMIT_FAILED');

 return {schema_version:1,id:id,current:target||'packaged',health:'offline_schema_passed',network_changed:false};
};
