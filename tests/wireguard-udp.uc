import {load_store} from '/usr/share/gale/lib/store.uc';
import {connection_config} from '/usr/share/gale/lib/connection.uc';
import {readfile,writefile,mkdtemp,chmod,unlink,rmdir} from 'fs';
let profile=filter(values(load_store().profiles),p=>p.model.protocol=='wireguard')[0];if(!profile)die('WIREGUARD_PROFILE_REQUIRED');
let selected=connection_config(profile),dir=mkdtemp('/tmp/gale-probe-XXXXXX');chmod(dir,0o700);
selected.config.log={level:'debug',timestamp:false};selected.config.inbounds[0].listen_port=17891;
writefile(dir+'/config.json',sprintf('%J',selected.config));chmod(dir+'/config.json',0o600);writefile(dir+'/core','sing-box');writefile(dir+'/binary',selected.binary);
let code=system(['/usr/share/gale/wireguard-udp-probe',dir],16000),log=lc(readfile(dir+'/core.log')||'');
let result={scope:'isolated_userspace_wireguard',udp_dns_passed:code==0,probe_exit:code,handshake_initiations:length(match(log,/sending handshake initiation/g)||[]),handshake_responses:length(match(log,/received handshake response/g)||[]),startup_fatal:index(log,'fatal')>=0,endpoint_timeout:index(log,'timeout')>=0,private_keys_disclosed:false};
if(result.startup_fatal){result.category=index(log,'bind')>=0?'BIND_ERROR':index(log,'dns')>=0?'DNS_ERROR':index(log,'not supported')>=0?'RUNTIME_UNSUPPORTED':'STARTUP_FAILED';}
result.udp=json(readfile(dir+'/result.json')||'{}');print(result);for(let f in ['config.json','binary','core','core.log','core.pid','result.json'])unlink(dir+'/'+f);rmdir(dir);
