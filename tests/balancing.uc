import {balanced_dispatcher} from '/usr/share/gale/lib/balancing.uc';
import {core_path} from '/usr/share/gale/lib/cores.uc';
import {mkdtemp,writefile,unlink,rmdir} from 'fs';
let c=balanced_dispatcher(2),dir=mkdtemp('/tmp/gale-native-XXXXXX');
assert(length(c.outbounds)==3,'missing closed fallback');assert(c.outbounds[2].protocol=='blackhole','direct fallback introduced');
writefile(dir+'/config.json',sprintf('%J',c));let code=system(['/usr/share/gale/capture',dir+'/output',core_path('xray'),'run','-test','-c',dir+'/config.json'],5000);
for(let f in ['config.json','output'])unlink(dir+'/'+f);rmdir(dir);assert(code==0,'native balancer schema rejected');
print({native_balancer_schema:true,strategy:'roundRobin',members:2,handshake_tested:false});
