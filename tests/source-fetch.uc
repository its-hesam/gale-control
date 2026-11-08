import { fetch_source } from '/usr/share/gale/lib/sources.uc';
try {
 let body=fetch_source('https://raw.githubusercontent.com/XTLS/Xray-examples/main/README.md');
 assert(type(body)=='string' && length(body)>0,'empty public HTTPS response');
 print({ok:true,bytes:length(body),scope:'real_router_public_HTTPS_fetch_only'});
} catch(e) {print({ok:false,error:e.message,scope:'real_router_public_HTTPS_fetch_only'});exit(1);}
