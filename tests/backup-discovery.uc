import {restore_catalog} from '/usr/share/gale/lib/backup.uc';
import {extract_profiles} from '/usr/share/gale/lib/profiles.uc';
import {extract_public_links,catalog_candidates,public_candidates} from '/usr/share/gale/lib/source-discovery.uc';
let passed=0;function ok(v){if(!v)die('ASSERT_FAILED');passed++;}
let raw='vless://00000000-0000-4000-8000-000000000001@example.com:443?security=tls&type=ws#Fixture';
let links=extract_public_links('<a href="'+raw+'">one</a>\n'+raw);ok(links==raw);
let p=extract_profiles(raw).profiles[0],store={profiles:{},sources:{},security:{allow_insecure:false}};store.profiles[p.id]={...p,enabled:true,native_status:'passed',last_test:{ok:true}};
let restored=restore_catalog({format:'gale-catalog',version:1,store:store});ok(!restored.profiles[p.id].enabled);ok(restored.profiles[p.id].native_status=='not_checked');ok(!restored.profiles[p.id].last_test);
let rejected=false;try{restore_catalog({format:'not-gale',version:1,store:store});}catch(e){rejected=true;}ok(rejected);
catalog_candidates('[{"url":"https://example.com/token-secret","name":"Fixture"}]',store,{id:'fixture'});ok(length(public_candidates(store))==1);ok(index(sprintf('%J',public_candidates(store)),'token-secret')<0);
print({passed:passed,network_changed:false,scope:'backup_validation_and_discovery_extraction'});
