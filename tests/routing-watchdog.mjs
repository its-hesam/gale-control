import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
function ssh(command,input){const r=spawnSync('ssh',['-o','BatchMode=yes','root@192.168.10.1',command],{input,encoding:'utf8',timeout:15000});assert.equal(r.status,0,r.stderr);return r.stdout}
const setup=`import {readfile,writefile,stat,chmod} from 'fs';if(stat('/etc/gale/routing-test/armed'))die('TRIAL_ALREADY_ARMED');let uptime=+split(readfile('/proc/uptime'),' ')[0];writefile('/etc/gale/routing-test/armed',sprintf('%J',{simulation:true,deadline_uptime:uptime+3,boot_id:trim(readfile('/proc/sys/kernel/random/boot_id'))}));chmod('/etc/gale/routing-test/armed',0o600);`;
ssh('ucode -',setup);ssh('/etc/init.d/gale-route-watch enable && /etc/init.d/gale-route-watch start');
// The timer must survive termination of the SSH invocation that started it.
let done=false;for(let i=0;i<12;i++){await new Promise(r=>setTimeout(r,1000));const s=ssh('test ! -f /etc/gale/routing-test/armed && echo DISARMED || echo ARMED');if(s.trim()==='DISARMED'){done=true;break}}
assert(done,'independent watchdog did not disarm');const result=JSON.parse(ssh('cat /etc/gale/routing-test/result.json'));assert.equal(result.state,'simulation_rolled_back');assert.equal(result.network_trial_active,false);ssh('! /etc/init.d/gale-route-watch enabled');
console.log('PASS independent procd watchdog expired, disarmed and disabled itself in simulation; no routing/firewall commands executed');
