import {readfile,writefile,mkdir,stat,chmod} from 'fs';
import {firewall_preview} from '/usr/share/gale/lib/firewall-plan.uc';
import {core_path} from '/usr/share/gale/lib/cores.uc';
let dir='/etc/gale/ipv6-stage';if(!stat(dir))mkdir(dir);chmod(dir,0o700);
let draft=json(readfile('/etc/gale/routing-active.json')),dns=json(readfile('/etc/gale/routing-test/dns.json')),tcp=json(readfile('/etc/gale/routing-test/tcp.json'));
let plan=firewall_preview(draft,true,true);dns.inbounds[0].listen='::';let v6=json(sprintf('%J',tcp.inbounds[0]));v6.tag='transparent6';v6.listen='::1';if(length(tcp.inbounds)!=1)die('IPV6_ALREADY_PREPARED');push(tcp.inbounds,v6);
for(let name,body in {'rules.nft':plan.nft,'batch.nft':'delete table inet gale_preview\n'+plan.nft,'dns.json':sprintf('%J',dns),'tcp.json':sprintf('%J',tcp)}){writefile(dir+'/'+name,body);chmod(dir+'/'+name,0o600);}
for(let item in [{id:'xray',file:'tcp.json'},{id:'sing-box',file:'dns.json'}])if(system(['/usr/share/gale/capture',dir+'/native-output',core_path(item.id),item.id=='xray'?'run':'check',...(item.id=='xray'?['-test']:[]),'-c',dir+'/'+item.file],5000)!=0)die('IPV6_BRIDGE_SCHEMA_REJECTED');
if(system(['/usr/sbin/nft','-c','-f',dir+'/batch.nft'],5000)!=0)die('IPV6_NFT_SCHEMA_REJECTED');print({prepared:true,network_changed:false,scope:'all_LAN_VPN_only'});
