import { validate_user_agent, fetch_source } from '/usr/share/gale/lib/sources.uc';
for(let value in ['','v2rayN','v2rayNG','Clash','clash.meta','sing-box','CustomClient/1.2 (Linux; armv7)'])assert(validate_user_agent(value)===value,'valid agent rejected');
let long='';for(let i=0;i<257;i++)long+='a';
for(let value in ['agent\r\nX-Evil: injected','agent\nheader','agent\tbad',long,null,123]) {let rejected=false;try{validate_user_agent(value);}catch(e){rejected=true;}assert(rejected,'unsafe agent accepted');}
print({passed:13,scope:'user_agent_validation'});
