import {readfile,stat,writefile} from 'fs';
// Protect only this small rollback guard from memory pressure during the trial.
writefile('/proc/self/oom_score_adj','-1000');
let dir='/etc/gale/routing-test',preserve_ipv6=false;
for(let attempt=0;stat(dir+'/armed');attempt++){
 let armed;try{armed=json(readfile(dir+'/armed')||'{}');}catch(e){break;}
 let uptime=+split(readfile('/proc/uptime')||'0',' ')[0],boot=trim(readfile('/proc/sys/kernel/random/boot_id')||'');
 if(armed.session===true){
  if(armed.boot_id!=boot){let settings;try{settings=json(readfile('/etc/gale/network-options.json')||'{}');}catch(e){}preserve_ipv6=!!settings?.ipv6_tunnel&&!!stat('/etc/gale/ipv6-before/committed');break;}if(!stat('/etc/gale/runtime/active')&&!stat('/etc/gale/core-upgrade.pending')&&!stat('/etc/gale/recovery/pending.json'))break;
  if(attempt>5&&system(['/usr/sbin/nft','list','table','inet','gale_preview'],3000)!=0)break;
  system(['/bin/sleep','3'],4000);continue;
 }
 if(attempt>=31)break;
 if(armed.boot_id!=boot||!(type(armed.deadline_uptime) in ['int','double'])||uptime>=armed.deadline_uptime)break;
 system(['/bin/sleep','3'],4000);
}
if(stat(dir+'/armed')){let simulation=false;try{simulation=json(readfile(dir+'/armed')||'{}').simulation===true;}catch(e){}system(['/usr/share/gale/routing-rollback',simulation?'--simulation':preserve_ipv6?'--preserve-ipv6':'--execute'],15000);}
