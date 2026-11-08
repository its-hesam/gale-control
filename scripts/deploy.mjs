import {spawnSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
const target='root@192.168.10.1';
function run(args,input){const r=spawnSync('ssh',['-o','BatchMode=yes',target,...args],{input,encoding:input instanceof Buffer?undefined:'utf8',maxBuffer:8*1024*1024});if(r.status!==0)throw new Error(String(r.stderr));return String(r.stdout)}
const baseline=run(['sha256sum /etc/config/network /etc/config/firewall /etc/config/wireless /etc/config/dhcp /etc/config/dropbear /etc/config/uhttpd']);
const archive=spawnSync('tar',['-czf','-','dist','router'],{maxBuffer:8*1024*1024});if(archive.status!==0)throw new Error('Package failed');
run(['mkdir -p /tmp/gale-foundation-stage && tar -xzf - -C /tmp/gale-foundation-stage'],archive.stdout);
console.log(run(['sh'],readFileSync('scripts/install-router.sh','utf8').replace(/\r/g,'')));
console.log(run(['sh'],readFileSync('scripts/install-scheduler.sh','utf8').replace(/\r/g,'')));
const after=run(['sha256sum /etc/config/network /etc/config/firewall /etc/config/wireless /etc/config/dhcp /etc/config/dropbear /etc/config/uhttpd']);
if(baseline!==after)throw new Error('Existing config changed; inspect before proceeding');
console.log('All six existing configuration hashes unchanged. SSH command succeeded after installation.');
