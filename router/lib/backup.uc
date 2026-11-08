import {extract_profiles} from '/usr/share/gale/lib/profiles.uc';
import {source_url,validate_user_agent} from '/usr/share/gale/lib/sources.uc';
export function restore_catalog(backup){
 if(backup?.format!='gale-catalog'||backup.version!=1||type(backup.store?.profiles)!='object'||type(backup.store?.sources)!='object')die('BAD_BACKUP_FORMAT');
 if(length(keys(backup.store.profiles))>2000||length(keys(backup.store.sources))>30)die('BACKUP_LIMIT');
 let store={schema_version:1,profiles:{},sources:{},security:{allow_insecure:!!backup.store.security?.allow_insecure}};
 for(let id,p in backup.store.profiles){
  if(type(p.original)!='string')die('BACKUP_PROFILE_MISSING_ORIGINAL');let result=extract_profiles(p.original),matches=filter(result.profiles,x=>x.id==id);if(length(matches)!=1)die('BACKUP_PROFILE_ID_MISMATCH');let next=matches[0];
  next.sources=filter(p.sources||[],s=>s=='manual'||exists(backup.store.sources,s));next.tls_mode=p.tls_mode in ['inherit','strict','insecure']?p.tls_mode:'inherit';
  if(p.openvpn_auth&&next.model.protocol=='openvpn'){for(let field in ['username','password'])if(type(p.openvpn_auth[field])!='string'||length(p.openvpn_auth[field])<1||length(p.openvpn_auth[field])>1024||match(p.openvpn_auth[field],/[[:cntrl:]]/))die('BAD_BACKUP_CREDENTIAL');next.openvpn_auth=p.openvpn_auth;}
  store.profiles[id]=next;
 }
 for(let id,s in backup.store.sources){let info=source_url(s.url);if(info.id!=id)die('BACKUP_SOURCE_ID_MISMATCH');store.sources[id]={...info,name:type(s.name)=='string'?substr(s.name,0,100):info.host,kind:s.kind in ['subscription','link_index','catalog']?s.kind:'subscription',enabled:false,public_untrusted:!!s.public_untrusted,refresh_interval:0,user_agent:validate_user_agent(s.user_agent||''),profile_ids:filter(s.profile_ids||[],p=>exists(store.profiles,p))};}
 return store;
};
