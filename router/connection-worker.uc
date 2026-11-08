import {readfile,writefile,rename,unlink,mkdir,chmod,stat,open} from 'fs';
import {load_store} from '/usr/share/gale/lib/store.uc';
import {connection_config} from '/usr/share/gale/lib/connection.uc';
import {balanced_dispatcher} from '/usr/share/gale/lib/balancing.uc';
import {core_path} from '/usr/share/gale/lib/cores.uc';
import {event_add} from '/usr/share/gale/lib/events.uc';
import {initial_candidate} from '/usr/share/gale/lib/selection.uc';
let root='/tmp/gale-connection',guard=open(root+'/worker.lock','a',0o600);if(!guard||!guard.lock('xn'))exit(0);

let req=json(readfile(root+'/request.json')||'{}'),runtime='/etc/gale/runtime';
function save(state,error){writefile(root+'/operation.new',sprintf('%J',{state:state,error:error||null,updated_at:time()}));rename(root+'/operation.new',root+'/operation.json');event_add('connection',error||state,req.id);}
let core_guard=open('/etc/gale/core-manager.lock','a',0o600);if(!core_guard||!core_guard.lock('xn')){save('failed','CORE_MANAGER_BUSY');exit(0);}
let files=['config.json','binary','active','sidecars','sidecar-1.json','sidecar-2.json','binary-1','binary-2'];
let previous={};for(let f in files)previous[f]=readfile(runtime+'/'+f);
try{
 save('preparing');
 let store=load_store();req.id=initial_candidate(req,store,time());let p=store.profiles[req.id];if(!p||p.native_status!='passed')die('NATIVE_VALIDATION_REQUIRED');
 let selected=connection_config(p,store.security);
 if(!stat(runtime))mkdir(runtime);chmod(runtime,0o700);
 let sides=[];
 if(req.mode=='balanced'){
  let mem=match(readfile('/proc/meminfo')||'',/MemAvailable:\s*([0-9]+)/);if(!mem||+mem[1]<229376)die('BALANCED_RAM_BUDGET');
  for(let i=0;i<length(req.pool);i++){
   let member=store.profiles[req.pool[i]];if(member?.native_status!='passed')die('NATIVE_VALIDATION_REQUIRED');
   let side=connection_config(member,store.security),n=i+1;
   if(side.core=='xray')side.config.inbounds[0].port=17900+n;else side.config.inbounds[0].listen_port=17900+n;
   writefile(runtime+'/candidate-'+n+'.json',sprintf('%J',side.config));chmod(runtime+'/candidate-'+n+'.json',0o600);
   if(system(['/usr/share/gale/capture',root+'/native-output',side.binary,side.core=='xray'?'run':'check',...(side.core=='xray'?['-test']:[]),'-c',runtime+'/candidate-'+n+'.json'],5000)!=0)die('BALANCED_MEMBER_SCHEMA_REJECTED');
   push(sides,{number:n,binary:side.binary});
  }
  selected={core:'xray',binary:core_path('xray'),config:balanced_dispatcher(length(sides))};
 }
 writefile(runtime+'/candidate.json',sprintf('%J',selected.config));chmod(runtime+'/candidate.json',0o600);
 let args=[selected.binary,selected.core=='xray'?'run':'check',...(selected.core=='xray'?['-test']:[]),'-c',runtime+'/candidate.json'];
 if(system(['/usr/share/gale/capture',root+'/native-output',...args],5000)!=0)die('CONNECTION_SCHEMA_REJECTED');
 if(req.lan&&!req.auto_connect&&stat('/etc/gale/network-options.json')){if(system(['/usr/share/gale/network-guard-remove'],20000)!=0)die('PERSISTENT_GUARD_REMOVE_FAILED');}
 save('starting');
 // A power loss during a multi-file commit must fail closed on the next boot.
 writefile(runtime+'/pending','1');chmod(runtime+'/pending',0o600);
 for(let side in sides){if(!rename(runtime+'/candidate-'+side.number+'.json',runtime+'/sidecar-'+side.number+'.json'))die('CONNECTION_COMMIT_FAILED');writefile(runtime+'/binary-'+side.number,side.binary+'\n');chmod(runtime+'/binary-'+side.number,0o600);}
 writefile(runtime+'/sidecars',''+length(sides)+'\n');chmod(runtime+'/sidecars',0o600);
 if(!rename(runtime+'/candidate.json',runtime+'/config.json'))die('CONNECTION_COMMIT_FAILED');
 writefile(runtime+'/binary',selected.binary+'\n');chmod(runtime+'/binary',0o600);
 writefile(runtime+'/active',sprintf('%J',{profile_id:req.id,core:selected.core,compatibility_version:selected.compatibility_version||null,started_at:time(),mode:req.mode||'manual',pool_scope:req.pool_scope||'selected',pool:req.pool||[req.id],policy:req.policy,auto_connect:!!req.auto_connect,scope:'loopback_proxy_only'}));chmod(runtime+'/active',0o600);
 unlink(root+'/health.json');
 unlink(root+'/udp.json');
 unlink(runtime+'/pending');
 if(system(['/etc/init.d/gale-tunnel','restart'],8000)!=0)die('CONNECTION_SERVICE_FAILED');
 if(req.auto_connect)system(['/etc/init.d/gale-tunnel','enable'],3000);else system(['/etc/init.d/gale-tunnel','disable'],3000);
 // The health service independently confirms HTTPS; running is not called connected.
 save('running_unverified');
 if(req.lan){core_guard.close();guard.close();system(['/usr/share/gale/lan-launch'],2000);}
}catch(e){
 for(let f in files){if(previous[f]!=null){writefile(runtime+'/'+f,previous[f]);chmod(runtime+'/'+f,0o600);}else unlink(runtime+'/'+f);}
 unlink(runtime+'/pending');
 system(['/etc/init.d/gale-tunnel',previous.active!=null?'restart':'stop'],8000);
 save('failed',match(e.message||'',/^[A-Z0-9_]+$/)?e.message:'CONNECTION_FAILED');
}
unlink(runtime+'/candidate.json');unlink(root+'/native-output');
 for(let i=1;i<=2;i++)unlink(runtime+'/candidate-'+i+'.json');
