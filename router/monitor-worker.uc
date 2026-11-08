import {readfile,writefile,rename,chmod} from 'fs';
import {connect} from 'ubus';
let bus=connect();
while(true){
 try{
  let data=bus.call('gale-status','status',{}),connection=bus.call('gale-connection','status',{}),wan=filter(data?.interfaces||[],i=>i.name=='wan')[0];
  let sample={at:time(),uptime:data?.system?.uptime,cpu_ticks:data?.system?.cpu_ticks,memory_available:data?.system?.memory?.available,memory_total:data?.system?.memory?.total,wan_rx:wan?.rx_bytes,wan_tx:wan?.tx_bytes,healthy:!!connection?.health?.ok&&time()-(connection?.health?.checked_at||0)<60,latency_ms:connection?.health?.latency_ms,health_checked_at:connection?.health?.checked_at,running:!!connection?.running,routing_active:!!connection?.routing?.active,guard_active:!!connection?.routing?.persistent_guard_active};
  let history=[];try{history=json(readfile('/tmp/gale-monitor.json')||'[]');}catch(e){}push(history,sample);history=slice(history,-2880);if(writefile('/tmp/gale-monitor.new',sprintf('%J',history))){chmod('/tmp/gale-monitor.new',0o600);rename('/tmp/gale-monitor.new','/tmp/gale-monitor.json');}
 }catch(e){}
 system(['/bin/sleep','30'],31000);
}
