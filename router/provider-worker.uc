import {readfile,writefile,rename,open,chmod,stat} from 'fs';import {sha256} from 'digest';
import {fetch_provider} from '/usr/share/gale/lib/provider-fetch.uc';import {provider_map,repository_files,provider_extract} from '/usr/share/gale/lib/providers.uc';import {lock_store,load_store,save_store} from '/usr/share/gale/lib/store.uc';import {duplicate_index,existing_profile} from '/usr/share/gale/lib/dedup.uc';
let root='/tmp/gale-providers',lock=open(root+'/worker.lock','a',0o600);if(!lock||!lock.lock('xn'))exit(0);let job=json(readfile(root+'/job.json')||'{}');if(job.state!='queued')exit(0);
function save(){job.updated_at=time();writefile(root+'/job.new',sprintf('%J',job));rename(root+'/job.new',root+'/job.json');}
function cache(id,doc){let path='/etc/gale/provider-catalogs/'+id+'.json';writefile(path+'.new',sprintf('%J',doc));chmod(path+'.new',0o600);if(!rename(path+'.new',path))die('PROVIDER_CATALOG_WRITE_FAILED');}
function fetch(url){return fetch_provider(url);}
function cancelled(){return !!stat(root+'/cancel')||!!stat('/etc/gale/recovery/pending.json');}
try{let provider=provider_map(load_store())[job.provider_id];if(!provider)die('BAD_PROVIDER');let catalog;
 if(job.action in ['scan','refresh']){
  job.state='scanning';save();
  if(provider.kind=='github'){let ref=replace(provider.ref,/\//g,'%2F'),commit=match(ref,/^[a-f0-9]{40}$/)?ref:json(fetch('https://api.github.com/repos/'+provider.repository+'/git/ref/heads/'+ref))?.object?.sha;if(!match(commit||'',/^[a-f0-9]{40}$/))die('REPOSITORY_REF_NOT_FOUND');let tree=json(fetch('https://api.github.com/repos/'+provider.repository+'/git/trees/'+commit+'?recursive=1'));catalog={provider_id:provider.id,revision:commit,tree_sha:tree.sha,scanned_at:time(),files:repository_files(provider,tree)};}
  else if(provider.kind=='surfshark'){
   let archive=fetch('https://my.surfshark.com/vpn/api/v1/server/configurations');writefile(root+'/surfshark.zip',archive);chmod(root+'/surfshark.zip',0o600);
   if(system(['/bin/sh','-c','/usr/share/gale/provider-zip list >/tmp/gale-providers/zip-list'],10000)!=0)die('PROVIDER_ZIP_LIST_FAILED');
   let locations=[];try{locations=json(fetch('https://api.surfshark.com/v4/server/clusters'));}catch(e){}
   let files=[];for(let line in split(readfile(root+'/zip-list')||'','\n')){let name=match(line,/([a-z0-9-]+\.prod\.surfshark\.com_(tcp|udp)\.ovpn)\s*$/)?.[1];if(!name)continue;let host=replace(name,/_(tcp|udp)\.ovpn$/,''),location=filter(locations,l=>l.connectionName==host)[0];push(files,{path:name,bytes:0,country_hint:location?.countryCode||uc(substr(name,0,2)),location:location?.location,protocol_hint:'openvpn',format:'openvpn',available:true,engine_available:true});}
   if(!length(files)||length(files)>1000)die('PROVIDER_CATALOG_INVALID');catalog={provider_id:provider.id,revision:sha256(archive),scanned_at:time(),verification:'official_https_download',files:files};
  }else die('OFFICIAL_ACCOUNT_EXPORT_REQUIRED');if(cancelled())die('PROVIDER_CANCELLED');cache(provider.id,catalog);
  let guard=lock_store(),store=load_store();store.providers=store.providers||{};store.providers[provider.id]={...(store.providers[provider.id]||provider),last_scan:time(),last_error:null};save_store(store);guard.close();job.catalog_files=length(catalog.files);job.state='complete';
 }
 if(job.action in ['fetch','refresh']){
  catalog=json(readfile('/etc/gale/provider-catalogs/'+provider.id+'.json')||'null');if(!catalog)die('SCAN_PROVIDER_FIRST');job.state='fetching';save();
  if(provider.kind=='surfshark'&&(!stat(root+'/surfshark.zip')||sha256(readfile(root+'/surfshark.zip'))!=catalog.revision))die('RESCAN_SURFSHARK_DOWNLOAD_CACHE');
  for(let path in job.files){if(cancelled()){job.state='cancelled';break;}let file=filter(catalog.files,f=>f.path==path&&f.available)[0];if(!file)die('PROVIDER_FILE_CHANGED');job.current_file=path;save();
   try{let body;if(provider.kind=='github')body=fetch('https://raw.githubusercontent.com/'+provider.repository+'/'+catalog.revision+'/'+path);else{if(!match(path,/^[a-z0-9-]+\.prod\.surfshark\.com_(tcp|udp)\.ovpn$/))die('BAD_SURFSHARK_FILE');if(system(['/bin/sh','-c','/usr/share/gale/provider-zip read '+path+' >/tmp/gale-providers/config'],10000)!=0)die('PROVIDER_ZIP_READ_FAILED');body=readfile(root+'/config');}
    let parsed;try{parsed=provider_extract(body,job.limit);}catch(e){parsed={profiles:[],errors:[{code:match(e.message||'',/^[A-Z0-9_]+$/)?e.message:'FORMAT_NOT_SUPPORTED'}]};}
    if(!length(parsed.profiles)){let guard=lock_store(),store=load_store();store.provider_assets=store.provider_assets||{};let id=sha256(provider.id+'|'+path);if(!store.provider_assets[id]&&length(keys(store.provider_assets))>=20)die('PROVIDER_ASSET_LIMIT');store.provider_assets[id]={provider_id:provider.id,file:path,protocol_hint:file.protocol_hint,sha256:sha256(body),content:body,received_at:time(),engine_available:false};save_store(store);guard.close();job.archived=(job.archived||0)+1;die(parsed.errors[0]?.code||'NO_IMPORTABLE_PROFILES');}if(cancelled())die('PROVIDER_CANCELLED');let guard=lock_store(),store=load_store();store.providers=store.providers||{};let current=store.providers[provider.id]||provider,index=duplicate_index(store);current.profile_ids=current.profile_ids||[];let file_added=0,file_duplicates=0;
    for(let p in parsed.profiles){let id=existing_profile(p,store,index);if(id){file_duplicates++;p=store.profiles[id];}else{p.sources=['provider:'+provider.id];store.profiles[p.id]=p;file_added++;}p.provider_memberships=p.provider_memberships||{};p.provider_memberships[provider.id]={file:path,country_hint:file.country_hint,trust:provider.access=='public'?'untrusted':'owner_selected',fetched_at:time(),revision:catalog.revision};if(p.model.protocol=='openvpn'&&current.credentials)p.openvpn_auth=current.credentials;if(!(p.id in current.profile_ids))push(current.profile_ids,p.id);}
    current.selected_files=job.files;current.last_fetch=time();current.last_error=null;store.providers[provider.id]=current;save_store(store);guard.close();job.added+=file_added;job.duplicates+=file_duplicates;job.rejected+=length(parsed.errors);if(parsed.sampled)job.sampled=true;for(let err in slice(parsed.errors,0,5))push(job.errors,{file:path,code:match(err.code||'',/^[A-Z0-9_]+$/)?err.code:'PROFILE_REJECTED'});
   }catch(e){push(job.errors,{file:path,code:match(e.message||'',/^[A-Z0-9_]+$/)?e.message:'PROVIDER_FILE_FAILED'});job.rejected++;}
   job.processed++;save();
  }if(job.state!='cancelled')job.state=length(job.errors)?'complete_with_errors':'complete';
 }
}catch(e){job.state=e.message=='PROVIDER_CANCELLED'?'cancelled':'failed';job.error=match(e.message||'',/^[A-Z0-9_]+$/)?e.message:'PROVIDER_WORKER_FAILED';}
job.finished_at=time();save();
