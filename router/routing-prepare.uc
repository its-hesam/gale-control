import {firewall_preview} from '/usr/share/gale/lib/firewall-plan.uc';
import {dns_bridge_config,transparent_bridge_config} from '/usr/share/gale/lib/network-plan.uc';
import {readfile,writefile,mkdir,stat,chmod} from 'fs';
import {core_path} from '/usr/share/gale/lib/cores.uc';
import {sha256} from 'digest';
if(stat('/etc/gale/routing-test/armed'))die('ROUTING_ALREADY_ACTIVE');
let raw=readfile('/etc/gale/routing-active.json')||readfile('/etc/gale/routing-draft.json');if(!raw)die('ROUTING_DRAFT_REQUIRED');let draft=json(raw),udp=ARGV[0] in ['udp','session'],options=json(readfile('/etc/gale/network-options.json')||'{}'),plan=firewall_preview(draft,udp,!!options.ipv6_tunnel);
if(ARGV[0]!='session'&&(draft.default_action!='vpn'||length(draft.rules)))die('TIMED_TEST_REQUIRES_ALL_LAN_WITHOUT_EXCEPTIONS');
let dir='/etc/gale/routing-test';if(!stat(dir))mkdir(dir);chmod(dir,0o700);
let dns=dns_bridge_config();dns.inbounds[0].listen=options.ipv6_tunnel?'::':'0.0.0.0';dns.inbounds[0].listen_port=5354;
let tcp=transparent_bridge_config(udp);if(options.ipv6_tunnel){let v6=json(sprintf('%J',tcp.inbounds[0]));v6.tag='transparent6';v6.listen='::1';push(tcp.inbounds,v6);}
writefile(dir+'/rules.nft',plan.nft);writefile(dir+'/dns.json',sprintf('%J',dns));writefile(dir+'/tcp.json',sprintf('%J',tcp));writefile(dir+'/trial-mode',udp?'tcp_udp\n':'tcp_only\n');
writefile(dir+'/binary-dns',core_path('sing-box')+'\n');writefile(dir+'/binary-tcp',core_path('xray')+'\n');writefile(dir+'/draft.json',raw);
let manifest='';for(let f in ['rules.nft','dns.json','tcp.json','binary-dns','binary-tcp','draft.json','trial-mode']){chmod(dir+'/'+f,0o600);manifest+=sha256(readfile(dir+'/'+f))+'  '+f+'\n';}writefile(dir+'/manifest.sha256',manifest);chmod(dir+'/manifest.sha256',0o600);
let checks=[];
for(let item in [{core:'sing-box',file:'dns.json'},{core:'xray',file:'tcp.json'}]){let code=system(['/usr/share/gale/capture',dir+'/check-output',core_path(item.core),item.core=='xray'?'run':'check',...(item.core=='xray'?['-test']:[]),'-c',dir+'/'+item.file],5000);push(checks,{core:item.core,native_schema:code==0});}
let nft=system(['/usr/sbin/nft','-c','-f',dir+'/rules.nft'],5000);
print({scope:'prepared_files_and_dry_run_only',native:checks,nft_dry_run:nft==0,network_changed:false,plan:plan});
