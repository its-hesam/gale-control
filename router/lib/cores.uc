import {readfile,stat} from 'fs';
export function core_state(){let raw=readfile('/etc/gale/cores.json');if(!raw)return {};try{return json(raw);}catch(e){die('CORE_REGISTRY_CORRUPT');}};
export function core_path(id){
 if(!(id in ['xray','sing-box']))die('BAD_CORE');
 let version=core_state()[id]?.current;
 if(version){if(!match(version,/^[0-9]+\.[0-9]+\.[0-9]+$/))die('BAD_CORE_VERSION');let path='/usr/share/gale/managed/'+id+'/'+version+'/core';if(!stat(path))die('ACTIVE_CORE_MISSING');return path;}
 return '/usr/bin/'+id;
};

export function compatibility_xray(){
 let version='25.12.8',dir='/usr/share/gale/managed/xray/'+version,receipt;
 try{receipt=json(readfile(dir+'/receipt.json')||'{}');}catch(e){die('COMPATIBILITY_CORE_RECEIPT_INVALID');}
 if(receipt.id!='xray'||receipt.version!=version||receipt.verification!='official_github_asset_sha256'||!stat(dir+'/core'))die('COMPATIBILITY_CORE_REQUIRED');
 return {binary:dir+'/core',compatibility_version:version,compatibility_reason:'TLS_allowInsecure'};
};

export function managed_feature_core(id,version,reason){
 if(id!='sing-box'||version!='1.14.4')die('BAD_FEATURE_CORE');let dir='/usr/share/gale/managed/'+id+'/'+version,receipt;
 try{receipt=json(readfile(dir+'/receipt.json')||'{}');}catch(e){die('FEATURE_CORE_RECEIPT_INVALID');}
 if(receipt.id!=id||receipt.version!=version||receipt.verification!='official_github_asset_sha256'||!stat(dir+'/core'))die('FEATURE_CORE_REQUIRED');
 return {binary:dir+'/core',feature_version:version,feature_reason:reason};
};
