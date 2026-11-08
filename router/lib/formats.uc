import {core_config} from '/usr/share/gale/lib/adapter.uc';import {native_json_models} from '/usr/share/gale/lib/native-json.uc';
import {writefile,readfile,mkdtemp,chmod,unlink,rmdir} from 'fs';import {clash_model} from '/usr/share/gale/lib/clash.uc';
export function yaml_document(text){let dir=mkdtemp('/tmp/gale-format-XXXXXX');if(!dir)die('FORMAT_STORAGE_FAILED');chmod(dir,0o700);let result,error;
 try{writefile(dir+'/input',text);chmod(dir+'/input',0o600);if(system(['/usr/bin/timeout','4','/usr/bin/lua','/usr/share/gale/yaml-to-json.lua',dir+'/input',dir+'/output'],5000)!=0)die('CLASH_YAML_PARSE_FAILED');result=json(readfile(dir+'/output')||'null');}catch(e){error=e.message;}
 unlink(dir+'/input');unlink(dir+'/output');rmdir(dir);if(error)die(error);return result;
};
export function clash_profiles(root){
 if(type(root.proxies)!='array'||length(root.proxies)>500)die('BAD_CLASH_PROXY_LIST');let models=[],errors=[],index={};for(let p in root.proxies){if(type(p.name)=='string'){if(exists(index,p.name))die('CLASH_DUPLICATE_NAME');index[p.name]=p;}}
 for(let i,p in root.proxies)try{
  if(root.gale_clash_root&&root.gale_clash_root!=p.name)continue;
  if(!p['dialer-proxy']){push(models,{model:clash_model(p),original:sprintf('%J',{proxies:[p]})});continue;}
  let nodes=[],outbounds=[],seen={},family=null,current=p;
  while(current){if(length(nodes)>=9)die('CLASH_CHAIN_DEPTH_LIMIT');if(seen[current.name])die('CLASH_DETOUR_CYCLE');seen[current.name]=true;push(nodes,current);let clean=json(sprintf('%J',current)),ref=clean['dialer-proxy'];delete clean['dialer-proxy'];let selected=core_config({model:clash_model(clean),tls_mode:'inherit'});if(family&&family!=selected.core)die('CLASH_MIXED_CORE_CHAIN');family=selected.core;if(length(selected.config.outbounds)!=1||length(selected.config.endpoints||[]))die('CLASH_CHAIN_NODE_NOT_SUPPORTED');let out=selected.config.outbounds[0];out.tag=current.name;if(ref){if(type(ref)!='string'||!index[ref])die('CLASH_DETOUR_NOT_FOUND');if(family=='xray'){out.streamSettings=out.streamSettings||{};out.streamSettings.sockopt=out.streamSettings.sockopt||{};out.streamSettings.sockopt.dialerProxy=ref;}else out.detour=ref;}push(outbounds,out);current=ref?index[ref]:null;}
  let native=native_json_models({gale_root:p.name,outbounds:outbounds});if(length(native.models)!=1)die(native.errors[0]?.code||'CLASH_CHAIN_REJECTED');push(models,{model:native.models[0].model,original:sprintf('%J',{gale_clash_root:p.name,proxies:nodes})});
 }catch(e){push(errors,{line:i+1,code:match(e.message||'',/^[A-Z0-9_]+$/)?e.message:'CLASH_PROXY_REJECTED'});}return {models:models,errors:errors};
};
