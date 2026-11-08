import {connection_config} from '/usr/share/gale/lib/connection.uc';import {mkdtemp,readfile,writefile,chmod,unlink,rmdir,lsdir,stat} from 'fs';import {sha256} from 'digest';
function doc(path){try{return json(readfile(path)||'null');}catch(e){return null;}}
function summary(samples){if(!length(samples))return {samples:0,mean_ms:null,min_ms:null,max_ms:null,jitter_ms:null};let total=0,jitter=0,smallest=samples[0],largest=samples[0];for(let i,n in samples){total+=n;if(n<smallest)smallest=n;if(n>largest)largest=n;if(i){let delta=n-samples[i-1];jitter+=delta<0?-delta:delta;}}return {samples:length(samples),mean_ms:total/length(samples),min_ms:smallest,max_ms:largest,jitter_ms:length(samples)>1?jitter/(length(samples)-1):null};}
export function performance_probe(profile,policy){let selected=connection_config(profile,policy),dir=mkdtemp('/tmp/gale-probe-XXXXXX');if(!dir)die('PROBE_STORAGE_FAILED');chmod(dir,0o700);
 if(selected.core=='xray')selected.config.inbounds[0].port=17891;else selected.config.inbounds[0].listen_port=17891;
 let result={tested_at:time(),scope:'bounded_proxy_benchmark',measurement_key:sha256(selected.binary+sprintf('%J',selected.config)),core:selected.core,download_mbps:null,upload_mbps:null,udp_response_loss_percent:null,traffic_budget_bytes:1310720,errors:[]};
 try{
  writefile(dir+'/config.json',sprintf('%J',selected.config));chmod(dir+'/config.json',0o600);writefile(dir+'/binary',selected.binary);writefile(dir+'/core',selected.core);let dns='1.1.1.1';if(profile.model.protocol=='wireguard'){let p=trim(split(profile.model.parameters.interface.DNS||'',',')[0]);if(p in ['8.8.8.8','8.8.4.4'])dns=p;}writefile(dir+'/dns-target',dns);
  if(system(['/usr/share/gale/capture',dir+'/native-output',selected.binary,selected.core=='xray'?'run':'check',...(selected.core=='xray'?['-test']:[]),'-c',dir+'/config.json'],5000)!=0)die('PROBE_NATIVE_SCHEMA_REJECTED');
  if(system(['/usr/share/gale/performance-probe',dir],60000)!=0)die('PERFORMANCE_WORKER_FAILED');
  let https=[],udp=[],sent=0,received=0,skipped=0;
  for(let n=1;n<=3;n++){let sample=doc(dir+'/https-'+n+'.json');if(sample?.http_code==204)push(https,sample.time_total*1000);}
  for(let n=1;n<=5;n++){let sample=doc(dir+'/udp-'+n+'.json');if(stat(dir+'/udp-sent-'+n)){sent++;if(sample?.ok&&sample.packet_received){received++;push(udp,sample.latency_ms);}}else skipped++;}
  result.https=summary(https);result.https.attempted=3;result.udp=summary(udp);result.udp.sent=sent;result.udp.received=received;result.udp.preflight_failures=skipped;result.udp.target=dns+':53';result.udp_response_loss_percent=sent?100*(sent-received)/sent:null;
  let down=doc(dir+'/download.json'),up=doc(dir+'/upload.json');if(down?.http_code==200&&down.size_download>0&&down.time_total>0){result.download_mbps=down.size_download*8/down.time_total/1000000;result.download_bytes=down.size_download;}else push(result.errors,'DOWNLOAD_TARGET_UNAVAILABLE');
  if(up?.http_code>=200&&up.http_code<300&&up.size_upload>0&&up.time_total>0){result.upload_mbps=up.size_upload*8/up.time_total/1000000;result.upload_bytes=up.size_upload;}else push(result.errors,'UPLOAD_TARGET_UNAVAILABLE');result.ok=length(https)>0;
 }catch(e){result.ok=false;push(result.errors,match(e.message||'',/^[A-Z0-9_]+$/)?e.message:'PERFORMANCE_FAILED');}
 for(let f in lsdir(dir)||[])unlink(dir+'/'+f);rmdir(dir);return result;
};
