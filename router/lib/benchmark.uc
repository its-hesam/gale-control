import {resolve_public_endpoint} from '/usr/share/gale/lib/addresses.uc';
import {pin_additional_remotes} from '/usr/share/gale/lib/connection.uc';
import {pin_target} from '/usr/share/gale/lib/dial.uc';
import { mkdtemp, writefile, readfile, unlink, rmdir } from 'fs';
import { public_ipv4 } from '/usr/share/gale/lib/sources.uc';
import {core_path} from '/usr/share/gale/lib/cores.uc';
import { core_config } from '/usr/share/gale/lib/adapter.uc';
export function probe_profile(profile, policy) {
 let selected=core_config(profile,policy),config=selected.config,dir=mkdtemp('/tmp/gale-probe-XXXXXX');
 if(!dir)die('PROBE_STORAGE_FAILED');
 let result={tested_at:time(),method:'tunnel_https_204',ok:false,latency_ms:null,error:null,core:selected.core,compatibility_version:selected.compatibility_version||null,endpoint:'https://www.gstatic.com/generate_204',bytes_limit:16384};
 try {
  let host=profile.model.endpoint.host;
  let family=profile.model.protocol=='openvpn'&&match(profile.model.parameters.remotes[0].protocol||profile.model.transport,/6(-client)?$/)?6:4,ips=resolve_public_endpoint(host,family);
  pin_target(selected,profile,ips[0]);pin_additional_remotes(selected,profile);
  config.inbounds=[{tag:'probe',listen:'127.0.0.1',port:17891,protocol:'socks',settings:{auth:'noauth',udp:false}}];
  if(selected.core=='sing-box')config.inbounds=[{type:'socks',tag:'probe',listen:'127.0.0.1',listen_port:17891}];
  if(!writefile(dir+'/binary',selected.binary||core_path(selected.core)))die('PROBE_STORAGE_FAILED');
  if(!writefile(dir+'/core',selected.core))die('PROBE_STORAGE_FAILED');
  if(!writefile(dir+'/config.json',sprintf('%J',config)))die('PROBE_STORAGE_FAILED');
  let native=system(['/usr/share/gale/capture',dir+'/native-output',selected.binary||core_path(selected.core),selected.core=='xray'?'run':'check',...(selected.core=='xray'?['-test']:[]),'-c',dir+'/config.json'],5000);
  if(native!=0)die('PROBE_NATIVE_SCHEMA_REJECTED');
  let exit_code=system(['/usr/share/gale/benchmark',dir],24000);
  let response;try{response=json(readfile(dir+'/result.json') || '{}');}catch(e){response={};}
  result.ok=exit_code==0 && response.http_code==204;
  if(result.ok)result.latency_ms=response.time_total*1000;
  else result.error='TUNNEL_HTTPS_FAILED';
 } catch(e) {result.error=match(e.message || '',/^[A-Z0-9_]+$/) ? e.message : 'PROBE_FAILED';}
 for(let file in ['binary','core','config.json','dns','core.log','core.pid','result.json','native-output'])unlink(dir+'/'+file);
 rmdir(dir);
 return result;
};
