import {firewall_preview} from '/usr/share/gale/lib/firewall-plan.uc';
let p=firewall_preview({default_action:'vpn',rules:[{ip:'192.168.10.20',action:'direct'}]});
assert(index(p.nft,'192.168.10.0/24')>=0,'all LAN scope lost');assert(index(p.nft,'192.168.10.20')>=0,'IP exception lost');assert(index(p.nft,'ip daddr @local4 return')>=0,'local management bypass lost');assert(index(p.nft,'hook output')<0,'router output interception added');assert(!p.ready_to_apply&&length(p.blockers)>=5,'incomplete plan represented as safe');
print({passed:5,scope:'unapplied_firewall_draft_only'});
