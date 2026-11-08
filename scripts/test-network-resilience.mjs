import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {writeFileSync} from 'node:fs';
if(!process.argv.includes('--approved-firewall-reload-and-bridge-failure')){console.log('Readiness only. Requires owner approval: reload firewall, stop Gale bridges for up to 20 seconds, verify blocking, restore bridges. No reboot or configuration edits.');process.exit(0);}
function ssh(script){const r=spawnSync('ssh',['-o','BatchMode=yes','root@192.168.10.1','sh'],{input:script,encoding:'utf8',timeout:25000});assert.equal(r.status,0,r.stderr);return r.stdout;}
let serial=0;async function call(sid,object,method,args={}){const r=await fetch('http://192.168.10.1/ubus',{method:'POST',headers:{'Content-Type':'application/json'},signal:AbortSignal.timeout(12000),body:JSON.stringify({jsonrpc:'2.0',id:++serial,method:'call',params:[sid,object,method,args]})});const b=await r.json();assert.equal(b.result?.[0],0);assert(!b.result[1]?.error,b.result[1]?.error);return b.result[1];}
const sid=(await call('0'.repeat(32),'session','login',{username:'root',password:'',timeout:300})).ubus_rpc_session;
let stopped=false,report={scope:'firewall_reload_and_bridge_failure',completed:false};const files='/etc/config/network /etc/config/firewall /etc/config/wireless /etc/config/dhcp /etc/config/dropbear /etc/config/uhttpd';
try{
 assert((await call(sid,'gale-connection','status')).routing?.active,'healthy LAN session required');
 const before=ssh('sha256sum '+files+'\n');
 const baseline=spawnSync('curl.exe',['--disable','--silent','--proxy','','--noproxy','*','--ipv4','--max-time','12','--output','NUL','--write-out','%{http_code}','https://www.gstatic.com/generate_204'],{encoding:'utf8',timeout:14000});assert.equal(baseline.status,0,'baseline HTTPS failed');assert.equal(baseline.stdout,'204');report.baseline_https_204=true;
 ssh('set -eu\n/sbin/fw4 check\n/etc/init.d/firewall reload\n');
 assert((await call(sid,'gale-connection','status')).routing?.active,'routing lost after firewall reload');report.firewall_reload_preserved_routing=true;
 // Detached recovery survives this SSH command and the host test process.
 stopped=true;ssh('set -eu\numask 077\ntouch /tmp/gale-connection/resilience-recovery-armed\n( sleep 20; if [ -f /tmp/gale-connection/resilience-recovery-armed ] && [ -f /etc/gale/routing-test/armed ]; then /etc/init.d/gale-route-bridges start; fi; rm -f /tmp/gale-connection/resilience-recovery-armed ) </dev/null >/dev/null 2>&1 &\nrecovery_pid=$!\nkill -0 "$recovery_pid"\n/etc/init.d/gale-route-bridges stop\n');
 const down=await call(sid,'gale-connection','status');assert(!down.routing?.active);assert(down.routing?.issues?.includes('DNS_BRIDGE_NOT_RUNNING'));report.bridge_failure_reported=true;
 const request=spawnSync('curl.exe',['--disable','--silent','--proxy','','--noproxy','*','--ipv4','--max-time','6','--output','NUL','https://www.gstatic.com/generate_204'],{timeout:8000});assert([7,28,52,56].includes(request.status),'Expected connection failure during bridge stop; curl exit '+request.status);report.client_https_blocked_during_bridge_failure=true;
 assert((await call(sid,'gale-status','status')).schema_version===1);report.management_api_reachable_during_failure=true;
 ssh('if [ -f /etc/gale/routing-test/armed ]; then /etc/init.d/gale-route-bridges start; fi\n');
 let restored=false;for(let i=0;i<12;i++){await new Promise(r=>setTimeout(r,1000));if((await call(sid,'gale-connection','status')).routing?.active){restored=true;break;}}assert(restored);report.bridges_restored=true;stopped=false;ssh('rm -f /tmp/gale-connection/resilience-recovery-armed\n');
 assert.equal(ssh('sha256sum '+files+'\n'),before);report.standard_configurations_unchanged=true;
 const requestAfter=spawnSync('curl.exe',['--disable','--silent','--proxy','','--noproxy','*','--ipv4','--max-time','12','--output','NUL','--write-out','%{http_code}','https://www.gstatic.com/generate_204'],{encoding:'utf8',timeout:14000});assert.equal(requestAfter.status,0);assert.equal(requestAfter.stdout,'204');report.client_https_restored=true;report.completed=true;
}catch(e){report.error=e.message;process.exitCode=1;}
finally{if(stopped)try{ssh('if [ -f /etc/gale/routing-test/armed ]; then /etc/init.d/gale-route-bridges start; fi\n')}catch(e){report.restore_failed=true;}await call(sid,'session','destroy');writeFileSync('docs/network-resilience-result.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report));}
