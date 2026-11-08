import {readfile,writefile,mkdir,stat,chmod} from 'fs';import {firewall_preview} from '/usr/share/gale/lib/firewall-plan.uc';import {validate_device_rules} from '/usr/share/gale/lib/network-plan.uc';import {network_guard_rules} from '/usr/share/gale/lib/network-guard.uc';import {sha256} from 'digest';
let raw=readfile('/etc/gale/routing-draft.json');if(!raw)die('ROUTING_DRAFT_REQUIRED');let draft=json(raw);if(!(draft.default_action in ['vpn','direct']))die('BAD_DEFAULT_ACTION');
validate_device_rules(map(draft.rules,r=>({ip:r.ip||r.observed_ip,action:r.action})),[]);
let dir='/etc/gale/routing-next';if(!stat(dir))mkdir(dir);chmod(dir,0o700);let plan=firewall_preview(draft,true,!!json(readfile('/etc/gale/network-options.json')||'{}').ipv6_tunnel),guard=network_guard_rules(draft);
for(let name in ['draft.json','rules.nft','batch.nft','forward.nft','input.nft']){let body=name=='draft.json'?raw:name=='rules.nft'?plan.nft:name=='batch.nft'?'delete table inet gale_preview\n'+plan.nft:name=='forward.nft'?guard.forward:guard.input;writefile(dir+'/'+name,body);chmod(dir+'/'+name,0o600);}
writefile(dir+'/draft.sha256',sha256(raw)+'  /etc/gale/routing-draft.json\n');chmod(dir+'/draft.sha256',0o600);
if(system(['/usr/sbin/nft','-c','-f',dir+'/batch.nft'],5000)!=0)die('POLICY_NFT_SCHEMA_REJECTED');print({prepared:true,network_changed:false});
