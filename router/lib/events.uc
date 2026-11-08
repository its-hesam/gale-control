import {readfile,writefile,rename,open,chmod} from 'fs';
export function event_log(){let raw=readfile('/tmp/gale-events.json');if(!raw)return [];try{let events=json(raw);return type(events)=='array'?events:[];}catch(e){return [];}};
export function event_add(type_name,code,profile_id){
 if(!match(type_name||'',/^[a-z_]{1,40}$/)||!match(code||'',/^[A-Za-z0-9_]{1,80}$/))return;
 let guard=open('/tmp/gale-events.lock','a',0o600);if(!guard||!guard.lock('xn'))return;
 let events=event_log(),event={at:time(),type:type_name,code:code};
 if(profile_id&&match(profile_id,/^[0-9a-f]{64}$/))event.profile_id=substr(profile_id,0,12);
 push(events,event);events=slice(events,-128);
 if(writefile('/tmp/gale-events.new',sprintf('%J',events))){chmod('/tmp/gale-events.new',0o600);rename('/tmp/gale-events.new','/tmp/gale-events.json');}
};
