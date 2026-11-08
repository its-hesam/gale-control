import {readfile,writefile,mkdtemp,unlink,rmdir} from 'fs';
import {xray_config} from '/usr/share/gale/lib/xray.uc';
let store=json(readfile('/etc/gale/state.json')),counts={};
for(let p in values(store.profiles)) {
 if(p.native_error!='CORE_SCHEMA_REJECTED')continue;
 let dir=mkdtemp('/tmp/gale-audit-XXXXXX');
 try {
  let config=xray_config(p,store.security);config.log.loglevel='warning';writefile(dir+'/config.json',sprintf('%J',config));
  system(['/usr/share/gale/capture',dir+'/out','/usr/bin/xray','run','-test','-c',dir+'/config.json'],5000);
  let text=lc(readfile(dir+'/out')||''),labels=[];
  for(let term in ['fingerprint','encryption','uuid','flow','removed','deprecated','certificate','alpn','invalid','unsupported','unknown','failed to parse','empty','reality','vision','xtls','password','publickey','allowinsecure','verify','tls','not supported','not allowed','disabled'])if(index(text,term)>=0)push(labels,term);
  let safe=map(split(text,/[^a-z]+/),w=>w in ['failed','to','start','main','load','config','files','infra','conf','build','outbound','with','tag','vpn','vless','encryption','tls','none','must','be','not','is','only','supported','for','invalid','should','use','please','settings','user','users','password','empty','or','and','non','requires','valid','protocol','it','has','been','removed','migrated','the','feature','specify','without','xtls','vision','reality','error'] ? w : '_');print({safe:join(' ',safe)});
  let key=join(',',labels);counts[key]=(counts[key]||0)+1;
 }catch(e) {counts.adapter=(counts.adapter||0)+1;}
 for(let f in ['config.json','out'])unlink(dir+'/'+f);rmdir(dir);break;
}
print({safe_keyword_counts:counts});
