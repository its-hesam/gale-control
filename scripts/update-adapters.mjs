import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {readFileSync,readdirSync} from 'node:fs';
const allowed=['transfer.uc','xhttp-extra.uc','dedup.uc','backup.uc','performance.uc','source-discovery.uc','selection.uc','discovery.uc','addresses.uc','core-activation.uc','core-recovery.uc','clash.uc','formats.uc','native-json.uc','firewall-plan.uc','network-guard.uc','openvpn.uc','wireguard.uc','udp.uc','routing-state.uc','profiles.uc','dial.uc','connection.uc','benchmark.uc','xray.uc','adapter.uc','cores.uc'];
const files=process.argv.slice(2);assert(files.length&&files.every(f=>allowed.includes(f)),'Explicit adapter file allowlist required');
function ssh(command,input){const r=spawnSync('ssh',['-o','BatchMode=yes','root@192.168.10.1',command],{input,encoding:'utf8',timeout:60000,maxBuffer:1024*1024});assert.equal(r.status,0,r.stderr);return r.stdout;}
if(ssh('test -f /etc/gale/releases.json && echo versioned || true').trim())throw new Error('Versioned installation: use node scripts/publish-release.mjs --activate');
const stage='/tmp/gale-adapter-stage';ssh('umask 077; mkdir -p '+stage+'/lib '+stage+'/backup; chmod 700 '+stage);
for(const name of readdirSync('router/lib').filter(f=>f.endsWith('.uc'))){const content=readFileSync('router/lib/'+name,'utf8').replaceAll('/usr/share/gale/lib/',stage+'/lib/');ssh('cat >'+stage+'/lib/'+name,content);}
for(const test of ['wireguard.uc','profiles.uc']){const output=ssh('ucode -',readFileSync('tests/'+test,'utf8').replaceAll('/usr/share/gale/lib/',stage+'/lib/'));console.log(output.trim());}
// Commit only reviewed adapters. Running cores, nft rules and route services are untouched.
for(const name of files){const script='set -eu; umask 077; if [ -f /usr/share/gale/lib/'+name+' ]; then cp /usr/share/gale/lib/'+name+' '+stage+'/backup/'+name+'; fi; cat >/usr/share/gale/lib/'+name+'.new; chmod 644 /usr/share/gale/lib/'+name+'.new; mv /usr/share/gale/lib/'+name+'.new /usr/share/gale/lib/'+name;ssh(script,readFileSync('router/lib/'+name));}
console.log('Updated adapters: '+files.join(', '));
