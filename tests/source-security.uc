import { source_url, public_ipv4 } from '/usr/share/gale/lib/sources.uc';
for (let ip in ['0.0.0.0','10.0.0.1','127.0.0.1','169.254.169.254','172.31.255.255','192.168.10.1','100.64.0.1','192.0.2.1','198.18.1.1','198.51.100.1','203.0.113.1','224.0.0.1','255.255.255.255','2130706433','0177.0.0.1','127.1','1.1.1.256']) assert(!public_ipv4(ip),'private/reserved/ambiguous accepted');
for (let ip in ['1.1.1.1','8.8.8.8','93.184.216.34']) assert(public_ipv4(ip),'public rejected');
for (let url in ['http://example.com/','https://user:pass@example.com/','https://[::1]/','https://localhost/','https://router.lan/','https://example.com/\nurl=https://evil.example']) {let blocked=false;try{source_url(url);}catch(e){blocked=true;}assert(blocked,'unsafe URL accepted');}
let s=source_url('https://raw.githubusercontent.com/example/repo/main/configs?token=test');assert(s.host=='raw.githubusercontent.com'&&s.port==443,'public HTTPS');
print({passed:27,scope:'URL_and_IP_SSRF_guards'});
