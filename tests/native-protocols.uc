import { parse_profile } from '/usr/share/gale/lib/profiles.uc';
import { xray_config, validate_xray } from '/usr/share/gale/lib/xray.uc';
import {core_config,validate_core} from '/usr/share/gale/lib/adapter.uc';
import { readfile } from 'fs';
let fixture=json(readfile('/usr/share/gale/selftests/xray-xhttp-reality.json'));
let public_key=fixture.outbounds[0].streamSettings.realitySettings.publicKey;
let examples=[
 'vless://00000000-0000-4000-8000-000000000001@203.0.113.1:443?type=xhttp&security=reality&sni=example.com&pbk='+public_key+'&sid=0123456789abcdef&path=%2Fvalidation-only&mode=auto&extra=%7B%22noSSEHeader%22%3Atrue%7D',
 'vmess://'+b64enc(sprintf('%J',{v:'2',ps:'Offline VMess',add:'203.0.113.1',port:'443',id:'00000000-0000-4000-8000-000000000001',aid:'0',net:'ws',type:'none',host:'example.com',path:'/validation-only',tls:'tls',sni:'example.com',scy:'auto'})),
 'trojan://offline-test-password@203.0.113.1:443?type=tcp&security=tls&sni=example.com',
 'ss://'+b64enc('2022-blake3-aes-128-gcm:AAAAAAAAAAAAAAAAAAAAAA==')+'@203.0.113.1:443'
];
let results=[];
for(let content in examples) {
 let profile=parse_profile(content),config=xray_config(profile),result=validate_xray(profile);
 assert(result.passed,'native schema rejected fixture');
 if(profile.model.transport=='xhttp')assert(config.outbounds[0].streamSettings.xhttpSettings.extra.noSSEHeader===true,'XHTTP extra lost');
 push(results,{protocol:profile.model.protocol,transport:profile.model.transport,security:profile.model.security,native_schema:result.passed,handshake_tested:false});
}
let unsupported=parse_profile(examples[0]+'&unmapped=retain');
let tls=parse_profile(examples[2]);
assert(xray_config(tls).outbounds[0].streamSettings.tlsSettings.allowInsecure===false,'secure default lost');
assert(xray_config(tls,{allow_insecure:true}).outbounds[0].streamSettings.tlsSettings.allowInsecure===true,'policy ignored');
let strict=parse_profile(examples[2]+'&allowInsecure=false');
assert(xray_config(strict,{allow_insecure:true}).outbounds[0].streamSettings.tlsSettings.allowInsecure===false,'explicit strict override lost');
let permissive=parse_profile(examples[2]+'&allowInsecure=true');
assert(xray_config(permissive).outbounds[0].streamSettings.tlsSettings.allowInsecure===true,'profile override ignored');
assert(core_config(permissive).core=='sing-box','insecure core selection wrong');
assert(validate_core(permissive).passed,'sing-box insecure native check failed');
assert(validate_core(parse_profile(examples[1]),{allow_insecure:true}).passed,'VMess sing-box native check failed');
let vless_tls=parse_profile('vless://00000000-0000-4000-8000-000000000001@203.0.113.1:443?type=ws&security=tls&sni=example.com');
assert(validate_core(vless_tls,{allow_insecure:true}).passed,'VLESS sing-box native check failed');
let xhttp_strict=parse_profile('vless://00000000-0000-4000-8000-000000000001@203.0.113.1:443?type=xhttp&security=tls&sni=example.com&allowInsecure=false');
assert(validate_core(xhttp_strict,{allow_insecure:true}).passed,'explicit strict XHTTP override failed');
let override=parse_profile('vless://00000000-0000-4000-8000-000000000001@203.0.113.1:443?type=xhttp&security=tls&sni=example.com');override.tls_mode='strict';
assert(validate_core(override,{allow_insecure:true}).passed,'per-profile strict override failed');
let bad=parse_profile(examples[2]+'&allowInsecure=yes'),bad_rejected=false;
try{core_config(bad);}catch(e){bad_rejected=true;}assert(bad_rejected,'invalid TLS policy accepted');
let rejected=false;try{xray_config(unsupported);}catch(e){rejected=true;}assert(rejected,'unknown fields silently dropped');
print({scope:'offline_native_schema_only',results:results});
