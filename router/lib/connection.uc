import {native_endpoint} from '/usr/share/gale/lib/native-json.uc';
import {wireguard_endpoint} from '/usr/share/gale/lib/wireguard.uc';
import {pin_target} from '/usr/share/gale/lib/dial.uc';
import {mkdtemp,readfile,unlink,rmdir} from 'fs';
import {core_config} from '/usr/share/gale/lib/adapter.uc';
import {core_path} from '/usr/share/gale/lib/cores.uc';
import {public_ipv4} from '/usr/share/gale/lib/sources.uc';
import {resolve_public_endpoint} from '/usr/share/gale/lib/addresses.uc';
export function pin_additional_remotes(selected,profile){
 if(profile.model.protocol=='native-json'){for(let i=1;i<length(selected.config.outbounds);i++){let out=selected.config.outbounds[i];if((out.protocol||out.type) in ['direct','freedom'])continue;let remote=native_endpoint(out,selected.core),view={core:selected.core,config:{outbounds:[out]}};pin_target(view,{model:{protocol:'native-json',endpoint:remote,parameters:{}}},resolve_public_endpoint(remote.host,index(remote.host,':')>=0?6:4)[0]);}return;}
 if(profile.model.protocol=='wireguard'){for(let i=1;i<length(selected.config.endpoints[0].peers);i++){let remote=wireguard_endpoint(profile.model.parameters.peers[i].Endpoint);selected.config.endpoints[0].peers[i].address=resolve_public_endpoint(remote.host,index(remote.host,':')>=0?6:4)[0];}return;}
 if(profile.model.protocol!='openvpn')return;
 let servers=selected.config.endpoints[0].servers;
 for(let i=1;i<length(servers);i++){
  let family=match(servers[i].network||'',/6$/)?6:4;servers[i].server=resolve_public_endpoint(servers[i].server,family)[0];
 }
};

export function connection_config(profile,policy){
 let selected=core_config(profile,policy),host=profile.model.endpoint?.host;if(!host)die('CONNECTION_ENDPOINT_REQUIRED');
 let family=profile.model.protocol=='openvpn'&&match(profile.model.parameters.remotes[0].protocol||profile.model.transport,/6(-client)?$/)?6:4,ips=resolve_public_endpoint(host,family);
 pin_target(selected,profile,ips[0]);
 pin_additional_remotes(selected,profile);
 if(selected.core=='xray')selected.config.inbounds=[{tag:'local-proxy',listen:'127.0.0.1',port:17890,protocol:'socks',settings:{auth:'noauth',udp:true}}];
 else selected.config.inbounds=[{type:'socks',tag:'local-proxy',listen:'127.0.0.1',listen_port:17890}];
 return {...selected,binary:selected.binary||core_path(selected.core)};
};
