import {parse_profile} from '/usr/share/gale/lib/profiles.uc';
import {core_config,validate_core} from '/usr/share/gale/lib/adapter.uc';
let fixtures=[
 'hy2://offline-password@203.0.113.1:443?sni=example.com&insecure=1&obfs=salamander&obfs-password=offline-obfs',
 'tuic://00000000-0000-4000-8000-000000000001:offline-password@203.0.113.1:443?sni=example.com&alpn=h3&congestion_control=bbr&udp_relay_mode=native',
 'anytls://offline-password@203.0.113.1:443?sni=example.com&allowInsecure=true'
],results=[];
for(let raw in fixtures){let p=parse_profile(raw),result=validate_core(p,{allow_insecure:false});assert(result.passed,'new protocol native schema failed');push(results,{protocol:p.model.protocol,core:result.core,native_schema:true,handshake_tested:false});}
let bad=parse_profile(fixtures[0]+'&unmapped=x'),rejected=false;try{core_config(bad);}catch(e){rejected=true;}assert(rejected,'unmapped option dropped');
print({scope:'native_schema_only',results:results});
