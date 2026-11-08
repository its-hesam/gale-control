import {parse_profile,metadata} from '/usr/share/gale/lib/profiles.uc';
import {core_config,validate_core} from '/usr/share/gale/lib/adapter.uc';
let raw='[Interface]\nPrivateKey = AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAE=\nAddress = 10.66.0.2/32\nDNS = 1.1.1.1\nMTU = 1408\n[Peer]\nPublicKey = AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAI=\nEndpoint = 203.0.113.1:51820\nAllowedIPs = 0.0.0.0/0\nPersistentKeepalive = 25\n';
let p=parse_profile(raw),selected=core_config(p),result=validate_core(p);
assert(selected.config.endpoints[0].system===false,'kernel interface requested');assert(selected.config.route.default_domain_resolver=='wg-dns','DNS detour missing');assert(result.passed,'WireGuard native schema rejected');
assert(index(sprintf('%J',metadata(p)),p.model.credentials.private_key)<0,'private key exposed');
let rejected=false;try{parse_profile(raw+'PostUp = bad\n');}catch(e){rejected=true;}assert(rejected,'unsafe directive accepted');
let multiple=parse_profile(replace(raw,'DNS = 1.1.1.1','DNS = 8.8.8.8, 8.8.4.4'));let dns_config=core_config(multiple).config.dns;assert(length(dns_config.servers)==2&&dns_config.strategy=='prefer_ipv4','DNS list or address strategy lost');assert(validate_core(multiple).passed,'multiple DNS native rejected');
print({native_wireguard_schema:true,system_interface:false,handshake_tested:false});
