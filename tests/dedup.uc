import {extract_profiles} from '/usr/share/gale/lib/profiles.uc';import {config_identity,duplicate_index,existing_profile} from '/usr/share/gale/lib/dedup.uc';
let a=extract_profiles('vless://00000000-0000-4000-8000-000000000001@example.com:443?security=tls&type=ws&path=%2Fvpn&sni=example.com#URI').profiles[0];
let b=extract_profiles(sprintf('%J',{proxies:[{name:'Clash',type:'vless',server:'example.com',port:443,uuid:'00000000-0000-4000-8000-000000000001',tls:true,servername:'example.com',network:'ws','ws-opts':{path:'/vpn'}}]})).profiles[0];
if(!a||!b||config_identity(a,{allow_insecure:false})!=config_identity(b,{allow_insecure:false}))die('CROSS_FORMAT_DEDUP_FAILED');
let store={profiles:{},security:{allow_insecure:false}};store.profiles[a.id]=a;let index=duplicate_index(store);if(existing_profile(b,store,index)!=a.id)die('DEDUP_EXISTING_ID_CHANGED');
b.tls_mode='insecure';if(config_identity(a,store.security)==config_identity(b,store.security))die('DEDUP_SECURITY_COLLISION');
print({passed:3,scope:'cross_format_equivalence_and_TLS_separation',network_changed:false});
