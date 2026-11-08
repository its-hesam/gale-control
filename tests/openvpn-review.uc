import {parse_profile,metadata} from '/usr/share/gale/lib/profiles.uc';
import {review_openvpn} from '/usr/share/gale/lib/openvpn.uc';
let raw='client\ndev tun\nproto udp\nremote example.com 1194\nauth-user-pass\nremote-cert-tls server\n<ca>\nOFFLINE-PLACEHOLDER-NOT-A-CERT\n</ca>\n';
let p=parse_profile(raw),r=review_openvpn(p.model);assert(r.static_review_passed&&r.credentials_required&&!r.native_schema_verified,'static/native scope conflated');assert(p.model.endpoint.port==1194,'remote not parsed');assert(index(sprintf('%J',metadata(p)),'OFFLINE-PLACEHOLDER')<0,'inline material exposed');
for(let suffix in ['up /bin/sh\n','config /etc/shadow\n','auth-user-pass /etc/shadow\n','unknown-directive enabled\n']){let rejected=false;try{review_openvpn(parse_profile(raw+suffix).model);}catch(e){rejected=true;}assert(rejected,'unsafe or unknown option accepted');}
print({passed:7,scope:'OpenVPN_static_review_only',handshake_tested:false});
