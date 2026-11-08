import {connectSSH} from './ssh-transport.mjs';import {pathToFileURL} from 'node:url';import {resolve} from 'node:path';
import assert from 'node:assert/strict';import {spawnSync} from 'node:child_process';import {readFileSync,writeFileSync} from 'node:fs';import {packageRelease} from './package-release.mjs';
export async function publishRelease({transport,target=process.env.GALE_SSH_TARGET||'root@192.168.10.1',routerUrl=process.env.GALE_ROUTER_URL,skipBuild=false,activate=false}={}){
assert(/^root@[A-Za-z0-9][A-Za-z0-9.-]*$/.test(target),'BAD_SSH_TARGET');const origin=new URL(routerUrl||'http://'+target.slice(5));assert(['http:','https:'].includes(origin.protocol)&&!origin.username&&!origin.password&&!origin.search&&!origin.hash&&origin.pathname==='/', 'BAD_ROUTER_ORIGIN');
const ssh=(command,input,timeout=60000)=>transport.exec(command,input,timeout);
if(!skipBuild)for(const args of [['node_modules/typescript/bin/tsc','--noEmit'],['node_modules/vite/bin/vite.js','build']]){let r=spawnSync(process.execPath,args,{stdio:'inherit'});assert.equal(r.status,0,'BUILD_FAILED');}
const p=packageRelease();assert(/^[a-z0-9-]{1,80}$/.test(p.id));
await ssh('test ! -e '+p.base+' && mkdir -p '+p.base+' && tar -xzf - -C '+p.base,p.archive);
let validate='set -eu\ncd '+p.base+'\nsha256sum -c SHA256SUMS >/dev/null\n';
for(const f of p.files){assert(/^[a-zA-Z0-9._/-]+$/.test(f.path)&&!f.path.split('/').includes('..'));validate+='chmod '+f.mode+' '+p.base+'/'+f.path+'\n';if(f.path.endsWith('.uc'))validate+='ucode -c -o /tmp/gale-release-check '+p.base+'/'+f.path+'\n';if(f.path.startsWith('helpers/')||f.path.startsWith('init/'))validate+='if head -n 1 '+p.base+'/'+f.path+' | grep -q \"^#!/bin/sh\"; then sh -n '+p.base+'/'+f.path+'; fi\n';if(f.path.startsWith('plugins/'))validate+='ucode '+p.base+'/'+f.path+' list >/dev/null\n';}
// Exported libraries are compiled through the imported entry points, not standalone.
validate=validate.split('\n').filter(line=>!line.startsWith('ucode -c')||!line.includes('/lib/')).join('\n')+'\nsync\n';await ssh('sh',validate);
writeFileSync('docs/staged-release.json',JSON.stringify({id:p.id,manifest_sha256:p.manifest_hash,files:p.files.length,validated:true,activated:false},null,2));
console.log(JSON.stringify({staged:p.id,files:p.files.length,validated:true}));if(!activate)return;
const holder=await transport.hold(`ucode -e 'import {open,readfile} from "fs";let l=open("/etc/gale/release.lock","a",0o600);if(!l||!l.lock("xn"))exit(1);let o=open("/dev/stdout","w");o.write("LOCKED\\n");o.flush();readfile("/dev/stdin");'`);
let prepared=false;
try{
 await ssh('test ! -f /etc/gale/recovery/pending.json && test ! -f /etc/gale/core-upgrade.pending');
 for(const [source,target] of [['router/release-recover.uc','/usr/share/gale-release-recover.uc'],['router/release-transaction.uc','/usr/share/gale-release-transaction.uc'],['router/gale-release-recovery.init','/etc/init.d/gale-release-recovery'],['router/state-recover.uc','/usr/share/gale-state-recover.uc'],['router/gale-state-recovery.init','/etc/init.d/gale-state-recovery']]){await ssh('cat >'+target+'.new',readFileSync(source));await ssh((target.endsWith('.uc')?'ucode -c -o /tmp/gale-release-anchor-check ':'sh -n ')+target+'.new && chmod '+(target.endsWith('.uc')?'644':'755')+' '+target+'.new && mv '+target+'.new '+target);}
 await ssh('/etc/init.d/gale-release-recovery enable && /etc/init.d/gale-state-recovery enable');
 const registry=await ssh('cat /etc/gale/releases.json 2>/dev/null || true');
 if(!registry.trim()){
  const id='bootstrap-'+Date.now(),base='/usr/share/gale/releases/'+id;let script='set -eu\numask 077\nmkdir -p '+base+'\n';
  for(const b of p.bindings){assert(/^\/(usr\/share\/gale\/|usr\/libexec\/rpcd\/gale-|etc\/init.d\/gale-|usr\/share\/rpcd\/acl.d\/gale-read.json$|www\/gale$)/.test(b.destination));script+='mkdir -p '+base+'/'+(b.directory?b.relative:b.relative.split('/').slice(0,-1).join('/'))+'\n';script+='if [ -e '+b.destination+' ]; then '+(b.directory?'cp -R '+b.destination+'/. '+base+'/'+b.relative+'/':'cp -L '+b.destination+' '+base+'/'+b.relative)+'; fi\n';}
  script+='printf \"Gale initial recovery point\\n\" >'+base+'/BOOTSTRAP\ncd '+base+'\nfind . -type f ! -name SHA256SUMS | sort | while IFS= read -r file; do sha256sum "$file"; done >SHA256SUMS\nsha256sum -c SHA256SUMS >/dev/null\nsync\n';await ssh('sh',script);
  const hash=(await ssh('sha256sum '+base+'/SHA256SUMS')).split(/\s+/)[0];await ssh('ucode /usr/share/gale-release-transaction.uc initial',JSON.stringify({id,manifest_hash:hash}));
 }
 // Stable anchors are installed once; subsequent releases only swap current.
 let bind='set -eu\n';for(const b of p.bindings){assert(/^\/[a-zA-Z0-9._/-]+$/.test(b.destination)&&!b.destination.split('/').includes('..'),'BAD_BINDING_DESTINATION');bind+='mkdir -p '+b.destination.slice(0,b.destination.lastIndexOf('/'))+'\n';}for(const b of p.bindings){const dst=b.destination,target='/usr/share/gale/current/'+b.relative;bind+='if [ -d '+dst+' ] && [ ! -L '+dst+' ]; then mv '+dst+' /root/gale-before-release-'+p.id+'-'+b.relative.replaceAll('/','-')+'; fi\nln -s '+target+' '+dst+'.release-new\nmv -Tf '+dst+'.release-new '+dst+'\n';}await ssh('sh',bind);
 await ssh('ucode /usr/share/gale-release-transaction.uc prepare',JSON.stringify({id:p.id,manifest_hash:p.manifest_hash}));prepared=true;
 await ssh('/etc/init.d/rpcd reload');
 const required=p.files.filter(f=>f.path.startsWith('plugins/')).map(f=>f.path.slice(8));
 const registryCheck='for name in '+required.join(' ')+'; do test "$(ubus list "$name")" = "$name" || exit 1; done';
 try{await ssh('sleep 1; '+registryCheck)}catch{await ssh('/etc/init.d/rpcd restart; sleep 2; '+registryCheck)}
 const status=JSON.parse(await ssh(p.base+'/plugins/gale-status call status','{}'));assert.equal(status.schema_version,1);
 const connection=JSON.parse(await ssh(p.base+'/plugins/gale-connection call status','{}'));assert(!connection.active||connection.running,'ACTIVE_ENGINE_MISSING');
 const html=await(await fetch(origin.origin+'/gale/',{signal:AbortSignal.timeout(10000)})).text();assert.equal(html,readFileSync('dist/index.html','utf8'),'PANEL_RELEASE_MISMATCH');
 const result=JSON.parse(await ssh('ucode /usr/share/gale-release-transaction.uc commit',JSON.stringify({id:p.id})));prepared=false;writeFileSync('docs/release-install-result.json',JSON.stringify({...result,manifest_sha256:p.manifest_hash,files:p.files.length,network_restarted:false},null,2));console.log(result);
}catch(e){if(prepared){await ssh('/etc/init.d/gale-release-recovery start');await ssh('/etc/init.d/rpcd reload');}throw e;}
finally{await holder.release();}
}

async function main(){const args=process.argv.slice(2);for(const arg of args)if(!['--skip-build','--activate','--password','--batch'].includes(arg))throw Error('Unknown publisher option.');if(args.includes('--password')&&args.includes('--batch'))throw Error('Choose either --password or --batch.');const target=process.env.GALE_SSH_TARGET||'root@192.168.10.1',transport=await connectSSH(target,{auth:args.includes('--password')?'password':args.includes('--batch')?'batch':'auto'});try{await publishRelease({transport,target,skipBuild:args.includes('--skip-build'),activate:args.includes('--activate')});}finally{await transport.close();}}
if(process.argv[1]&&pathToFileURL(resolve(process.argv[1])).href===import.meta.url)await main().catch(e=>{console.error('Publication failed: '+e.message);process.exitCode=1;});
