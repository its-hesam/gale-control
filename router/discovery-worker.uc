import {open,readfile,writefile,rename,stat} from 'fs';import {connect} from 'ubus';import {load_store} from '/usr/share/gale/lib/store.uc';
let dir='/tmp/gale-discovery',lock=open(dir+'/worker.lock','a',0o600);if(!lock||!lock.lock('xn'))exit(0);let job=json(readfile(dir+'/job.json')||'{}');if(job.state!='queued')exit(0);let bus=connect();
function save(){job.updated_at=time();writefile(dir+'/job.new',sprintf('%J',job));rename(dir+'/job.new',dir+'/job.json');}
function error(code){if(!match(code||'',/^[A-Z0-9_]+$/))code='DISCOVERY_CHECK_FAILED';job.errors[code]=(job.errors[code]||0)+1;}
function cancelled(){if(stat(dir+'/cancel')){job.state='cancelled';return true;}if(stat('/etc/gale/core-upgrade.pending')){job.state='interrupted';error('CORE_UPGRADE_RUNNING');return true;}return false;}
try{
 job.state='sources';let sources=filter(values(load_store().sources),s=>s.enabled);job.source_total=length(sources);save();
 for(let source in sources){if(cancelled())break;let r=bus.call('gale-sources','refresh',{id:source.id});job.source_processed++;let code=r?.error||r?.source?.last_error;if(code&&code!='SOURCE_COOLDOWN'){job.source_failed++;error(code);}save();}
 if(!(job.state in ['cancelled','interrupted'])){
  let items=values(load_store().profiles);items=sort(items,(a,b)=>(a.last_test?.tested_at||0)-(b.last_test?.tested_at||0));job.state='validating';save();let eligible=[];
  for(let p in items){if(cancelled()||length(eligible)>=job.limit)break;if(p.model.protocol=='openvpn'){job.skipped_openvpn++;continue;}if(p.source_retired)continue;if(p.native_status!='passed'){let r=bus.call('gale-profiles','validate',{id:p.id});job.validated++;if(!r?.passed){error(r?.error||'NATIVE_VALIDATION_FAILED');save();continue;}}push(eligible,p.id);save();}
  if(!(job.state in ['cancelled','interrupted'])){job.state='probing';save();for(let id in eligible){if(cancelled())break;let r=bus.call('gale-profiles','benchmark',{id:id});if(r?.error in ['PROBE_BUSY','PROBE_COOLDOWN'])job.skipped_busy++;else{job.probed++;if(r?.result?.ok)job.passed++;else error(r?.error||r?.result?.error||'PROBE_FAILED');}save();system(['/bin/sleep','1'],2000);}}
 }
 if(!(job.state in ['cancelled','interrupted']))job.state='complete';
}catch(e){job.state='failed';error(match(e.message||'',/^[A-Z0-9_]+$/)?e.message:'DISCOVERY_WORKER_FAILED');}
job.finished_at=time();save();
