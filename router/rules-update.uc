import {readfile,writefile,rename,chmod,open,unlink} from 'fs';import {sha256} from 'digest';import {iran_geoip} from '/usr/share/gale/lib/geoip.uc';
let root='/tmp/gale-rules',lock=open(root+'/worker.lock','a',0o600);if(!lock||!lock.lock('xn'))exit(0);
function state(s,error){writefile(root+'/job.json',sprintf('%J',{state:s,error:error,updated_at:time()}));}
function get(url,file,max){if(system(['/usr/share/gale/capture',file,'/usr/bin/curl','--disable','--fail','--silent','--proxy','','--proto','=https','--max-time','40','--max-filesize',''+max,'--user-agent','Gale-Rules',url],42000)!=0)die('RULE_DOWNLOAD_FAILED');return readfile(file);}
try{state('downloading');let commit=json(get('https://api.github.com/repos/Chocolate4U/Iran-v2ray-rules/commits/release',root+'/commit',1048576))?.sha;if(!match(commit||'',/^[a-f0-9]{40}$/))die('RULE_COMMIT_INVALID');
 let base='https://raw.githubusercontent.com/Chocolate4U/Iran-v2ray-rules/'+commit+'/',data=get(base+'geoip-lite.dat',root+'/data',1048576),expected=split(trim(get(base+'geoip-lite.dat.sha256sum',root+'/checksum',1024)),/\s+/)[0];state('verifying');
 if(!match(expected,/^[a-f0-9]{64}$/)||sha256(data)!=expected)die('RULE_CHECKSUM_MISMATCH');let cidrs=iran_geoip(data),body=sprintf('%J',{source:'Chocolate4U/Iran-v2ray-rules',category:'geoip:ir',commit:commit,sha256:expected,cidrs:cidrs,updated_at:time()});
 if(writefile('/etc/gale/iran-geoip.new',body)!=length(body))die('RULE_STORAGE_FAILED');chmod('/etc/gale/iran-geoip.new',0o600);if(!rename('/etc/gale/iran-geoip.new','/etc/gale/iran-geoip.json'))die('RULE_COMMIT_FAILED');state('ready');
}catch(e){state('failed',match(e.message||'',/^[A-Z0-9_]+$/)?e.message:'RULE_UPDATE_FAILED');}
for(let file in ['data','commit','checksum'])unlink(root+'/'+file);
