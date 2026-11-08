import {readfile,writefile,stat,lsdir,rename,chmod} from 'fs';
export function led_inventory(){let out=[];for(let name in lsdir('/sys/class/leds')||[]){if(!match(name,/^[A-Za-z0-9_:.-]{1,80}$/))continue;push(out,{name:name,max:+trim(readfile('/sys/class/leds/'+name+'/max_brightness')||'0')});}return out;};
export function led_config(){return json(readfile('/etc/gale/leds.json')||'{}');};
function led_write(name,file,value){if(!match(name||'',/^[A-Za-z0-9_:.-]{1,80}$/))die('BAD_LED');return writefile('/sys/class/leds/'+name+'/'+file,''+value)!=null;}
export function led_restore(){let snapshot=json(readfile('/etc/gale/leds-before.json')||'{}');for(let name in keys(snapshot)){let s=snapshot[name];led_write(name,'trigger','none');led_write(name,'brightness',s.brightness);led_write(name,'trigger',s.trigger);if(s.trigger=='timer'){led_write(name,'delay_on',s.on);led_write(name,'delay_off',s.off);}}};
export function led_save(req){
 let old=led_config();if(req.enabled!==true){led_restore();writefile('/etc/gale/leds.json','{"enabled":false}');return;}
 let list=led_inventory(),names=[req.connected,req.connecting,req.disconnected];for(let name in names)if(!length(filter(list,l=>l.name==name)))die('LED_NOT_FOUND');
 let snapshot=json(readfile('/etc/gale/leds-before.json')||'{}');if(old.enabled)led_restore();
 for(let name in names){if(snapshot[name])continue;let root='/sys/class/leds/'+name,tr=match(readfile(root+'/trigger')||'',/\[([^\]]+)\]/);snapshot[name]={trigger:tr?.[1]||'none',brightness:trim(readfile(root+'/brightness')||'0'),on:trim(readfile(root+'/delay_on')||'500'),off:trim(readfile(root+'/delay_off')||'500')};}
 writefile('/etc/gale/leds-before.json',sprintf('%J',snapshot));chmod('/etc/gale/leds-before.json',0o600);writefile('/etc/gale/leds.new',sprintf('%J',{enabled:true,connected:req.connected,connecting:req.connecting,disconnected:req.disconnected}));chmod('/etc/gale/leds.new',0o600);rename('/etc/gale/leds.new','/etc/gale/leds.json');
};
export function led_state(status){let cfg=led_config();if(!cfg.enabled)return 'disabled';let fresh=status?.health?.ok&&time()-(status.health.checked_at||0)<60&&status.running&&status.health.profile_id==status.active?.profile_id&&status.health.checked_at>=(status.active?.started_at||0),connecting=status?.operation?.state in ['queued','preparing','starting']||status?.running&&!status?.health?.checked_at,state=fresh&&status?.routing?.active?'connected':connecting?'connecting':'disconnected';
 let previous=readfile('/tmp/gale-led-applied')||'',signature=sprintf('%J',cfg)+state;if(previous==signature)return state;
 for(let name in [cfg.connected,cfg.connecting,cfg.disconnected]){led_write(name,'trigger','none');led_write(name,'brightness','0');}
 let name=cfg[state];led_write(name,'brightness',trim(readfile('/sys/class/leds/'+name+'/max_brightness')||'1'));
 if(state=='connecting'&&index(readfile('/sys/class/leds/'+name+'/trigger')||'','timer')>=0){led_write(name,'trigger','timer');led_write(name,'delay_on','350');led_write(name,'delay_off','350');}
 writefile('/tmp/gale-led-applied',signature);return state;
};
