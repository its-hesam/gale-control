import { mkdtemp, writefile, readfile, unlink, rmdir,open } from 'fs';
import { lock_store } from '/usr/share/gale/lib/store.uc';
import {core_path} from '/usr/share/gale/lib/cores.uc';
let guard=open('/etc/gale/probe.lock','a',0o600);
if(!guard || !guard.lock('xn'))die('PROBE_BUSY');
let lock=lock_store(),dir=mkdtemp('/tmp/gale-probe-XXXXXX');
if(!dir)die('TEMP_FAILED');
// Test the probe machinery with direct outbound. This is explicitly NOT a VPN test.
writefile(dir+'/binary',core_path('xray')+'\n');writefile(dir+'/core','xray\n');
writefile(dir+'/config.json',sprintf('%J',{log:{loglevel:'none'},inbounds:[{listen:'127.0.0.1',port:17891,protocol:'socks',settings:{auth:'noauth',udp:false}}],outbounds:[{protocol:'freedom'}]}));
let code=system(['/usr/share/gale/benchmark',dir],14000);
let response;try{response=json(readfile(dir+'/result.json') || '{}');}catch(e){response={};}
for(let file in ['binary','core','config.json','core.log','core.pid','result.json'])unlink(dir+'/'+file);
rmdir(dir);
let ok=code==0 && response.http_code==204;
print({ok:ok,http_status:response.http_code,exit_code:code,scope:'real_local_SOCKS_harness_with_direct_outbound_NOT_VPN'});
exit(ok ? 0 : 1);
