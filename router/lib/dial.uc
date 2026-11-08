import {pin_download} from '/usr/share/gale/lib/xhttp-extra.uc';
// Callers validate every resolved address before invoking this deterministic mapper.
export function pin_target(selected,profile,ip){
 let host=profile.model.endpoint.host,out=selected.config.outbounds[0]||{};
 if(selected.core=='xray'){
  if(out.settings.vnext)out.settings.vnext[0].address=ip;else out.settings.servers[0].address=ip;
  let stream=out.streamSettings||{};pin_download(stream);if(stream.tlsSettings&&!stream.tlsSettings.serverName)stream.tlsSettings.serverName=host;
  if(stream.grpcSettings){
   if(!stream.grpcSettings.authority)stream.grpcSettings.authority=profile.model.parameters.authority||profile.model.parameters.host||stream.tlsSettings?.serverName||stream.realitySettings?.serverName||host;
   if(stream.tlsSettings&&!stream.tlsSettings.alpn)stream.tlsSettings.alpn=['h2'];
  }
  if(stream.wsSettings&&!stream.wsSettings.headers.Host)stream.wsSettings.headers.Host=host;
  if(stream.xhttpSettings&&!stream.xhttpSettings.host)stream.xhttpSettings.host=host;
  if(stream.httpupgradeSettings&&!stream.httpupgradeSettings.host)stream.httpupgradeSettings.host=host;
 }else{
  if(out.tls?.enabled&&!out.tls.server_name)out.tls.server_name=host;
  if(profile.model.protocol=='openvpn')selected.config.endpoints[0].servers[0].server=ip;else if(profile.model.protocol=='wireguard')selected.config.endpoints[0].peers[0].address=ip;else out.server=ip;
  // sing-box gRPC has no authority override in this version; route gRPC to Xray.
  if(out.transport?.type=='grpc')die('GRPC_AUTHORITY_ADAPTER_REQUIRED');
  if(out.transport?.type=='ws'&&!out.transport.headers.Host)out.transport.headers.Host=host;
  if(out.transport?.type=='httpupgrade'&&!out.transport.host)out.transport.host=host;
 }
 return selected;
};
