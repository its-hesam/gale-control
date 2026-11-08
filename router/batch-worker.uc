import { open, readfile, writefile, rename, stat } from 'fs';
let dir='/tmp/gale-batch',guard=open(dir+'/worker.lock','a',0o600);
if(!guard || !guard.lock('xn'))exit(0);
let job=json(readfile(dir+'/job.json') || '{}');
if(job.state!='queued')exit(0);
function save(){job.updated_at=time();writefile(dir+'/job.new',sprintf('%J',job));rename(dir+'/job.new',dir+'/job.json');}
job.state='running';save();
for(let id in job.ids){
 if(stat(dir+'/cancel')){job.state='cancelled';break;}
 if(!match(id,/^[0-9a-f]{64}$/))continue;
 job.current_id=id;save();
 let code=system(['/usr/share/gale/capture',dir+'/result.json','/usr/share/gale/profile-task',job.kind,id],job.kind=='performance'?75000:26000);
 let response;try{response=json(readfile(dir+'/result.json') || '{}');}catch(e){response={};}
 for(let retry=0;retry<3&&response?.error=='STORE_BUSY';retry++){system(['/bin/sleep','1'],2000);code=system(['/usr/share/gale/capture',dir+'/result.json','/usr/share/gale/profile-task',job.kind,id],job.kind=='performance'?75000:26000);try{response=json(readfile(dir+'/result.json')||'{}');}catch(e){response={};}}
 let passed=code==0 && (job.kind=='validate' ? response.passed : response.result?.ok);
 if(passed)job.passed++;
 else {job.failed++;let error=response.error || response.result?.error || (job.kind=='validate' ? 'CORE_SCHEMA_REJECTED':'CHECK_FAILED');if(!match(error,/^[A-Z0-9_]+$/))error='CHECK_FAILED';job.errors[error]=(job.errors[error]||0)+1;}
 job.processed++;save();
 if(job.kind=='benchmark')system(['/bin/sleep','1'],2000);
}
if(job.state=='running')job.state='complete';
job.finished_at=time();delete job.current_id;save();
