import { parse_profile, extract_profiles, metadata } from '/usr/share/gale/lib/profiles.uc';
let good='vless://00000000-0000-4000-8000-000000000001@example.com:443?type=xhttp&security=reality&pbk=test&sid=abcd&path=%2Ftest&extra=%7B%22x%22%3A1%7D#Test';
let p=parse_profile(good);
assert(p.model.protocol=='vless' && p.model.transport=='xhttp' && p.model.security=='reality','protocol retention');
assert(p.model.parameters.extra=='{"x":1}' && p.original==good,'unknown extra and original retained');
assert(index(sprintf('%J',metadata(p)),'00000000-0000-4000-8000-000000000001')<0,'no UUID in list');
let q=parse_profile(replace(good,'#Test','#Renamed'));assert(q.id==p.id,'names excluded from dedup identity');
let cases=[
 'vless://bad@example.com:443',
 'vless://00000000-0000-4000-8000-000000000001@example.com:0',
 'vless://00000000-0000-4000-8000-000000000001@example.com:443?path=%0aevil',
 'vless://00000000-0000-4000-8000-000000000001@example.com:443?type=tcp&type=xhttp',
 'client\nremote example.com 443\nup /tmp/evil',
 '[Interface]\nPrivateKey = AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\nPostUp = evil\n[Peer]'
];
for (let item in cases) {let rejected=false;try{parse_profile(item);}catch(e){rejected=true;}assert(rejected,'unsafe input accepted');}
let b=extract_profiles(b64enc(good+'\n'+replace(good,'#Test','#Renamed')));assert(length(b.profiles)==2,'base64 subscription');
assert(p.handshake_status=='not_tested' && !p.enabled,'no false handshake or auto-enable');
print({passed:12,scope:'parser_and_redaction'});
