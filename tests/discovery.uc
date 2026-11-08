import {extract_profiles} from '/usr/share/gale/lib/profiles.uc';
import {discovery_report} from '/usr/share/gale/lib/discovery.uc';
let uri='vless://00000000-0000-4000-8000-000000000001@203.0.113.1:443?security=tls&type=ws&sni=example.com';
for(let envelope in [[uri],{links:[uri]},{profiles:[uri]}]){let parsed=extract_profiles(sprintf('%J',envelope));assert(length(parsed.profiles)==1&&!length(parsed.errors),'API envelope failed');}
let parsed=extract_profiles(uri),p=parsed.profiles[0];p.sources=['one','two'];p.native_status='passed';p.last_test={ok:true,tested_at:100,latency_ms:50};p.test_history=[{time:100,ok:true}];let store={profiles:{},sources:{one:{public_untrusted:true},two:{public_untrusted:false}}};store.profiles[p.id]=p;
let report=discovery_report(store,110);assert(report.cross_source_duplicates==1,'duplicate origin lost');assert(report.candidates[0].recommendable,'fresh success not ranked');assert(report.candidates[0].source_trust=='untrusted','trust upgraded implicitly');
assert(!discovery_report(store,1100).candidates[0].recommendable,'stale result recommended');
print({passed:7,scope:'JSON_source_envelopes_dedup_quality_and_trust'});
