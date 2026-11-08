import { fetch_source } from '/usr/share/gale/lib/sources.uc';
try {
 let body=fetch_source('https://httpbin.org/user-agent','Gale-UA-Test/1.0');
 let echo=json(body);
 assert(echo['user-agent']=='Gale-UA-Test/1.0','remote agent mismatch');
 print({ok:true,scope:'real_router_HTTPS_remote_UserAgent_echo',agent:'Gale-UA-Test/1.0'});
} catch(e) {print({ok:false,scope:'real_router_HTTPS_remote_UserAgent_echo',error:e.message});exit(1);}
