import {sha256} from 'digest';
import {extract_profiles} from '/usr/share/gale/lib/profiles.uc';
export const provider_templates=[
 {id:'config-collector',name:'Config Collector',kind:'github',repository:'miladtahanian/Config-Collector',ref:'main',prefix:'',selection:'collector',access:'public'},
 {id:'confighub',name:'ConfigHub',kind:'github',repository:'heliataromi/ConfigHub',ref:'subscription',prefix:'',selection:'hub',access:'public'},
 {id:'kamaji',name:'Kamaji',kind:'github',repository:'shabane/kamaji',ref:'master',prefix:'hub/',selection:'kamaji',access:'public'},
 {id:'openray',name:'OpenRay',kind:'github',repository:'sakha1370/OpenRay',ref:'main',prefix:'output/',selection:'openray',access:'public'},
 {id:'surfshark',name:'Surfshark',kind:'surfshark',access:'paid',portal:'https://my.surfshark.com/',protocols:['openvpn','wireguard'],account_login:'official_portal',automatic_download:'openvpn'},
 {id:'proton',name:'Proton VPN',kind:'portal',access:'free_and_paid',portal:'https://account.protonvpn.com/downloads',protocols:['wireguard','openvpn'],account_login:'official_portal',automatic_download:false}
];
export function provider_map(store){let result={};for(let p in provider_templates)result[p.id]={...p,...(store.providers?.[p.id]||{})};for(let id,p in store.providers||{})if(!result[id])result[id]=p;return result;};
export function public_provider(p){return {id:p.id,name:p.name,kind:p.kind,repository:p.repository,ref:p.ref,prefix:p.prefix,access:p.access,portal:p.portal,protocols:p.protocols,account_login:p.account_login,automatic_download:p.automatic_download,selected_files:p.selected_files||[],last_scan:p.last_scan,last_fetch:p.last_fetch,last_error:p.last_error,profile_count:length(p.profile_ids||[]),credentials_saved:!!p.credentials};};
export function validate_repository(req){
 if(!match(req.repository||'',/^[A-Za-z0-9_.-]{1,100}\/[A-Za-z0-9_.-]{1,100}$/))die('BAD_GITHUB_REPOSITORY');
 let ref=req.ref||'main',prefix=req.prefix||'';if(!match(ref,/^[A-Za-z0-9_.\/-]{1,100}$/)||index(ref,'..')>=0||!match(prefix,/^[A-Za-z0-9_.\/-]{0,160}$/)||index(prefix,'..')>=0||substr(prefix,0,1)=='/')die('BAD_REPOSITORY_LAYOUT');
 return {id:'repo-'+substr(sha256(req.repository+'|'+ref+'|'+prefix),0,20),kind:'github',name:substr(req.name||req.repository,0,100),repository:req.repository,ref:ref,prefix:prefix,access:'public',selection:'custom'};
};
export function repository_files(provider,tree){
 if(type(tree.tree)!='array'||length(tree.tree)>12000||tree.truncated)die('REPOSITORY_TREE_TOO_LARGE');let files=[];
 for(let entry in tree.tree){let path=entry.path;if(entry.type!='blob'||entry.mode=='120000'||!match(path||'',/^[A-Za-z0-9_.\/-]{1,240}$/)||index(path,'..')>=0||index(path,provider.prefix||'')!=0||!match(path,/\.(txt|json|yaml|yml|conf|ovpn)$/i))continue;
  let name=split(path,'/');name=name[length(name)-1];let base=replace(lc(name),/\.(txt|json|yaml|yml|conf|ovpn)$/,'');
  if(provider.selection=='collector'&&path!='mixed_iran.txt')continue;
  if(provider.selection=='hub'&&path=='telegram.txt')continue;
  if(provider.selection=='openray'&&!match(path,/^output\/(country\/|kind\/|all_valid_proxies\.txt$|Iran_valid_proxies\.txt$|converted\/)/))continue;
  if(provider.selection=='custom'&&match(path,/(^|\/)(\.github|\.state|tests|docs|node_modules|scripts)\//))continue;
  let code=match(path,/(^|\/)([a-zA-Z]{2})(_base64)?\.(txt|conf|ovpn)$/),country=code&&(match(path,/(^|\/)(country|countries)\//)||match(name,/^[A-Z]{2}\.txt$/))?uc(code[2]):null;
  let protocol=match(base,/(^|_)(vless|vmess|wireguard|openvpn|ikev2|l2tp|trojan|ssr|ss|socks|hy2|hysteria2|tuic|anytls)(_|$)/)?.[2]||'mixed';
  if(protocol=='ss')protocol='shadowsocks';if(protocol=='hy2')protocol='hysteria2';
  push(files,{path:path,bytes:entry.size||0,sha:entry.sha,country_hint:country,protocol_hint:protocol,format:match(path,/\.ovpn$/)?'openvpn':match(path,/\.conf$/)?'config':match(path,/\.ya?ml$/)?'clash':match(path,/\.json$/)?'json':index(base,'base64')>=0?'base64':'links',available:entry.size>0&&entry.size<=1048576,reason:entry.size==0?'EMPTY_UPSTREAM_FILE':entry.size>1048576?'FILE_EXCEEDS_1_MIB':null,engine_available:!(protocol in ['l2tp','ikev2','ssr'])});
 }if(length(files)>1000)die('PROVIDER_FILE_LIMIT');return files;
};
export function provider_extract(body,limit){
 if(type(limit)!='int'||limit<1||limit>200)die('BAD_PROVIDER_LIMIT');if(length(body)>1048576)die('SOURCE_SIZE');let text=trim(body),sampled=false;
 if(match(text,/^[A-Za-z0-9+\/_=\r\n-]+$/)&&length(text)>40){try{let decoded=b64dec(replace(text,/\s/g,''));if(index(decoded||'', '://')>=0)text=decoded;}catch(e){}}
 if(index(text,'://')>=0&&!match(text,/^(\{|\[|proxies:)/)){let lines=filter(split(text,/\r?\n/),l=>length(trim(l))&&!match(l,/^\s*#/));sampled=length(lines)>limit;text=join('\n',slice(lines,0,limit));}
 let parsed=extract_profiles(text);if(length(parsed.profiles)>limit){parsed.profiles=slice(parsed.profiles,0,limit);sampled=true;}return {...parsed,sampled:sampled};
};
export function provider_credentials(req){if(req.clear)return null;for(let key in ['username','password'])if(type(req[key])!='string'||length(req[key])<1||length(req[key])>1024||match(req[key],/[[:cntrl:]]/))die('BAD_SERVICE_CREDENTIALS');return {username:req.username,password:req.password};};
export function restore_provider_data(original,store){
 store.providers={};store.provider_assets={};if(length(keys(original.providers||{}))>20||length(keys(original.provider_assets||{}))>20)die('BACKUP_PROVIDER_LIMIT');
 for(let id,old in original.providers||{}){let base=filter(provider_templates,p=>p.id==id)[0]||validate_repository(old);if(base.id!=id)die('BACKUP_PROVIDER_ID');let files=old.selected_files||[];if(type(files)!='array'||length(files)>5)die('BACKUP_PROVIDER_FILES');for(let file in files)if(type(file)!='string'||length(file)>240||match(file,/[[:cntrl:]]/))die('BACKUP_PROVIDER_FILES');store.providers[id]={...base,selected_files:files,profile_ids:filter(old.profile_ids||[],id=>!!store.profiles[id]),credentials:old.credentials?provider_credentials(old.credentials):null};}
 for(let id,asset in original.provider_assets||{}){if(!store.providers[asset.provider_id]||type(asset.file)!='string'||length(asset.file)>240||type(asset.content)!='string'||length(asset.content)>1048576||sha256(asset.provider_id+'|'+asset.file)!=id||sha256(asset.content)!=asset.sha256)die('BACKUP_PROVIDER_ASSET');store.provider_assets[id]={provider_id:asset.provider_id,file:asset.file,content:asset.content,sha256:asset.sha256,protocol_hint:asset.protocol_hint,engine_available:false,received_at:asset.received_at};}
 for(let id,p in store.profiles){let original_memberships=original.profiles[id]?.provider_memberships||{};p.provider_memberships={};for(let provider_id,m in original_memberships){if(!store.providers[provider_id]||type(m.file)!='string'||length(m.file)>240)continue;p.provider_memberships[provider_id]={file:m.file,country_hint:match(m.country_hint||'',/^[A-Z]{2}$/)?m.country_hint:null,trust:m.trust=='untrusted'?'untrusted':'owner_selected'};}}
};
