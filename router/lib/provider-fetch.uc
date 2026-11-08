import {mkdtemp,readfile,stat,unlink,rmdir} from 'fs';import {fetch_source} from '/usr/share/gale/lib/sources.uc';
// Fixed public provider origins only; account secrets are never sent here.
export function fetch_provider(url){
 if(!match(url,/^https:\/\/(api\.github\.com|raw\.githubusercontent\.com|my\.surfshark\.com|api\.surfshark\.com)\//))die('PROVIDER_ORIGIN_NOT_ALLOWED');
 try{return fetch_source(url,'Gale-Provider-Manager');}catch(e){}
 // Router-origin DNS may be filtered even when the active LAN tunnel works.
 // Resolve at the existing VPN proxy; TLS validation stays enabled, no redirects.
 let dir=mkdtemp('/tmp/gale-provider-get-XXXXXX');if(!dir)die('PROVIDER_FETCH_STORAGE');let result,error;
 try{let code=system(['/usr/share/gale/capture',dir+'/status','/usr/bin/curl','--disable','--silent','--fail','--proxy','socks5h://127.0.0.1:17890','--noproxy','','--proto','=https','--max-redirs','0','--connect-timeout','5','--max-time','15','--max-filesize','1048576','--user-agent','Gale-Provider-Manager','--output',dir+'/body','--write-out','%{http_code}',url],17000);if(code!=0||trim(readfile(dir+'/status')||'')!='200')die('PROVIDER_DIRECT_AND_VPN_FETCH_FAILED');if(!stat(dir+'/body')?.size||stat(dir+'/body').size>1048576)die('SOURCE_SIZE');result=readfile(dir+'/body');}catch(e){error=e.message;}
 for(let file in ['status','body'])unlink(dir+'/'+file);rmdir(dir);if(error)die(error);return result;
};
