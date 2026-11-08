import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
const manifest=JSON.parse(readFileSync('scripts/feature-manifest.json'));
function ssh(command,input){const r=spawnSync('ssh',['-o','BatchMode=yes','root@192.168.10.1',command],{input,encoding:'utf8',timeout:60000,maxBuffer:1024*1024});assert.equal(r.status,0,r.stderr);return r.stdout;}
if(ssh('test -f /etc/gale/releases.json && echo versioned || true').trim())throw new Error('Versioned installation: use node scripts/publish-release.mjs --activate');
const stage='/tmp/gale-feature-stage';ssh('umask 077; mkdir -p '+stage);
for(const name of [...manifest.helpers,...manifest.plugins,...manifest.services.map(x=>x+'.init'),'gale-read.json'])ssh('cat >'+stage+'/'+name,readFileSync('router/'+name));
ssh('cat >'+stage+'/install-scheduler',readFileSync('scripts/install-scheduler.sh'));
const validate=[...manifest.helpers.filter(x=>x.endsWith('.uc')).map(x=>'ucode -c -o '+stage+'/check '+stage+'/'+x),...manifest.plugins.map(x=>'ucode '+stage+'/'+x+' list >/dev/null'),...manifest.helpers.filter(x=>!x.endsWith('.uc')&&!x.endsWith('.lua')).map(x=>'sh -n '+stage+'/'+x),'sh -n '+stage+'/install-scheduler'];
ssh('set -eu\n'+validate.join('\n'));
const pairs=[...manifest.helpers.map(x=>[x,'/usr/share/gale/'+x]),...manifest.plugins.map(x=>[x,'/usr/libexec/rpcd/'+x]),...manifest.services.map(x=>[x+'.init','/etc/init.d/'+x]),['gale-read.json','/usr/share/rpcd/acl.d/gale-read.json'],['install-scheduler','/usr/share/gale/install-scheduler']];
let script='set -eu\numask 077\n';
script+='set --\n';
for(const dest of [...pairs.map(x=>x[1]),'/usr/share/gale/lib'])script+='if [ -e "'+dest+'" ]; then set -- "$@" "'+dest+'"; fi\n';
script+='tar -czf /root/gale-before-feature-update.tgz "$@" 2>/dev/null\ntar -tzf /root/gale-before-feature-update.tgz >/dev/null\ntouch /etc/gale/code-update.pending\ntrap \'tar -xzf /root/gale-before-feature-update.tgz -C /; rm -f /etc/gale/code-update.pending; /etc/init.d/rpcd reload\' EXIT HUP INT TERM\n';
for(const [name,dest] of pairs)script+='cp '+stage+'/'+name+' '+dest+'.new\nchmod '+(dest.endsWith('.json')||dest.endsWith('.uc')?'644':'755')+' '+dest+'.new\nmv '+dest+'.new '+dest+'\n';
script+='if [ ! -f /etc/gale/routing-active.json ] && [ -f /etc/gale/routing-test/draft.json ]; then cp /etc/gale/routing-test/draft.json /etc/gale/routing-active.json; chmod 600 /etc/gale/routing-active.json; fi\n/etc/init.d/gale-core-recovery enable\n/etc/init.d/rpcd reload\nrm -f /etc/gale/code-update.pending\ntrap - EXIT HUP INT TERM\n';
ssh('sh',script);console.log('Compiled and installed feature APIs/helpers. Live tunnel and firewall unchanged.');
