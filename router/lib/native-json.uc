import {core_path,compatibility_xray} from '/usr/share/gale/lib/cores.uc';
function safe_tree(v,depth){if(depth>24)die('NATIVE_JSON_DEPTH_LIMIT');if(type(v)=='object'){for(let k in keys(v)){if(match(k,/(_path|_file|Path|File)$/)||match(k,/masterkeylog|key_log|downloadsettings/i))die('NATIVE_EXTERNAL_REFERENCE_NOT_SUPPORTED');safe_tree(v[k],depth+1);}}else if(type(v)=='array')for(let x in v)safe_tree(x,depth+1);}
export function native_endpoint(out,family){let host,port;if(family=='xray'){let servers=out.settings?.vnext||out.settings?.servers;if(type(servers)!='array'||length(servers)!=1)die('NATIVE_SINGLE_SERVER_REQUIRED');host=servers[0].address;port=servers[0].port;}else{host=out.server;port=out.server_port;}if(type(host)!='string'||!match(host,/^[A-Za-z0-9][A-Za-z0-9.:-]{0,252}$/)||type(port)!='int'||port<1||port>65535)die('BAD_NATIVE_ENDPOINT');return {host:lc(host),port:port};};
function references(out){let refs=[];if(out.detour)push(refs,out.detour);if(out.proxySettings?.tag)push(refs,out.proxySettings.tag);if(out.streamSettings?.sockopt?.dialerProxy)push(refs,out.streamSettings.sockopt.dialerProxy);for(let r in refs)if(type(r)!='string'||!length(r))die('BAD_NATIVE_DETOUR');return refs;}
function rewrite(out,names){if(out.detour)out.detour=names[out.detour];if(out.proxySettings?.tag)out.proxySettings.tag=names[out.proxySettings.tag];if(out.streamSettings?.sockopt?.dialerProxy)out.streamSettings.sockopt.dialerProxy=names[out.streamSettings.sockopt.dialerProxy];}
function chain_for(root,index,family){let ordered=[],visiting={},seen={};function walk(tag,depth){if(depth>8)die('NATIVE_CHAIN_DEPTH_LIMIT');if(visiting[tag])die('NATIVE_DETOUR_CYCLE');if(seen[tag])return;let out=index[tag];if(!out)die('NATIVE_DETOUR_NOT_FOUND');if((out.protocol?'xray':'sing-box')!=family)die('NATIVE_MIXED_CORE_CHAIN');safe_tree(out,0);let proto=out.protocol||out.type;if(proto in ['direct','freedom']){if(out.override_address||out.override_port||out.settings?.redirect)die('NATIVE_DIRECT_OVERRIDE_NOT_SUPPORTED');}else if(proto in ['vless','vmess','trojan','shadowsocks','socks','http','hysteria2','tuic','anytls'])native_endpoint(out,family);else die('NATIVE_CHAIN_NODE_NOT_SUPPORTED');if(length(ordered)>=16)die('NATIVE_CHAIN_SIZE_LIMIT');visiting[tag]=true;seen[tag]=true;push(ordered,tag);for(let ref in references(out))walk(ref,depth+1);delete visiting[tag];}walk(root,0);let names={};for(let i,tag in ordered)names[tag]=i?'gale-chain-'+i:'vpn';return map(ordered,tag=>{let out=json(sprintf('%J',index[tag]));out.tag=names[tag];rewrite(out,names);return out;});}
export function native_json_models(root){
 if(type(root.outbounds)!='array'||length(root.outbounds)>500)die('UNKNOWN_JSON_SCHEMA');let models=[],errors=[],index={};
 for(let i,out in root.outbounds){if(type(out)!='object')die('BAD_NATIVE_OUTBOUND');let tag=out.tag||('gale-out-'+i);if(exists(index,tag))die('NATIVE_DUPLICATE_TAG');index[tag]={...out,tag:tag};}
 for(let i,original in root.outbounds){try{
  let out=json(sprintf('%J',original)),family=out.protocol?'xray':out.type?'sing-box':null,proto=out.protocol||out.type,root_tag=out.tag||('gale-out-'+i);
  if(root.gale_root&&root.gale_root!=root_tag)continue;
  if(proto in ['direct','freedom','block','blackhole','dns','selector','urltest'])continue;
  if(family=='xray'&&!(proto in ['vless','vmess','trojan','shadowsocks','socks','http']))die('NATIVE_PROTOCOL_NOT_SUPPORTED');
  if(family=='sing-box'&&!(proto in ['vless','vmess','trojan','shadowsocks','socks','http','hysteria2','tuic','anytls']))die('NATIVE_PROTOCOL_NOT_SUPPORTED');
  if(!family)die('NATIVE_CORE_UNKNOWN');safe_tree(out,0);let endpoint=native_endpoint(out,family),chain=chain_for(root_tag,index,family),name=out.tag||('Native '+proto+' '+(i+1));out=chain[0];let security=family=='xray'?(out.streamSettings?.security||'none'):(out.tls?.enabled?'tls':'none');
  let parameters={native_family:family,outbound:out};if(length(chain)>1)parameters.chain=slice(chain,1);
  let preserved={outbounds:[original]};
  if(length(chain)>1){let reachable={},todo=[root_tag];while(length(todo)){let t=shift(todo);if(reachable[t])continue;reachable[t]=true;for(let r in references(index[t]))push(todo,r);}preserved={gale_root:root_tag,outbounds:map(keys(reachable),t=>index[t])};}
  push(models,{model:{protocol:'native-json',name:substr(name,0,100),endpoint:endpoint,transport:family=='xray'?(out.streamSettings?.network||'tcp'):(out.transport?.type||'tcp'),security:security,credentials:null,parameters:parameters},original:sprintf('%J',preserved)});
 }catch(e){push(errors,{line:i+1,code:match(e.message||'',/^[A-Z0-9_]+$/)?e.message:'NATIVE_OUTBOUND_REJECTED'});}}
 return {models:models,errors:errors,warnings:['Proxy outbounds imported; Gale controls inbounds, DNS and device routing.']};
};
export function native_json_config(profile){let p=profile.model.parameters,out=json(sprintf('%J',p.outbound)),family=p.native_family;if(!out||!(family in ['xray','sing-box']))die('NATIVE_PROFILE_REIMPORT_REQUIRED');let all=[out,...json(sprintf('%J',p.chain||[]))];for(let node in all)safe_tree(node,0);
 let selected={core:family,config:{log:family=='xray'?{loglevel:'none'}:{disabled:true},inbounds:[],outbounds:all}};if(family=='sing-box'&&length(all)>1)selected.config.route={final:'vpn'};
 if(family=='xray'&&length(filter(all,n=>!!n.proxySettings||n.streamSettings?.tlsSettings?.allowInsecure||(n.protocol=='vless'&&!(n.streamSettings?.security in ['tls','reality'])))))selected={...selected,...compatibility_xray()};
 return selected;
};
