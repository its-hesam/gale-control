import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
let sequence=0;async function call(sid,obj,method,args={}){const r=await fetch('http://192.168.10.1/ubus',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:++sequence,method:'call',params:[sid,obj,method,args]})});const b=await r.json();assert.equal(b.result?.[0],0);assert(!b.result[1]?.error,b.result[1]?.error);return b.result[1]}
const sid=(await call('0'.repeat(32),'session','login',{username:'root',password:'',timeout:180})).ubus_rpc_session;let started=false;
try{
 assert(!(await call(sid,'gale-connection','status')).active,'requires idle connection');
 const p=(await call(sid,'gale-profiles','list')).profiles.find(p=>p.protocol==='vmess'&&p.native_status==='passed'&&p.last_test?.ok);assert(p);
 await call(sid,'gale-connection','connect',{id:p.id,auto_connect:false});started=true;let ready=false;for(let i=0;i<40;i++){await new Promise(r=>setTimeout(r,1000));if((await call(sid,'gale-connection','status')).health?.ok){ready=true;break}}assert(ready);
 const script=`set -eu
umask 077
mkdir -p /tmp/gale-deps
chmod 700 /tmp/gale-deps
base=https://downloads.openwrt.org/releases/25.12.2/packages/arm_cortex-a7_neon-vfpv4/base
for file in packages.adb 'ucode-mod-socket-2026.01.16~85922056-r2.apk'; do
 /usr/bin/curl --disable --fail --silent --show-error --proxy '' --noproxy '' --socks5-hostname 127.0.0.1:17890 --proto '=https' --max-time 25 --max-filesize 2097152 --output "/tmp/gale-deps/$file" "$base/$file"
done
/usr/bin/apk verify /tmp/gale-deps/packages.adb
printf 'file:///tmp/gale-deps/packages.adb\n' >/tmp/gale-deps/repositories
/usr/bin/apk --repositories-file /tmp/gale-deps/repositories --no-network add --simulate ucode-mod-socket
`;
 const r=spawnSync('ssh',['-o','BatchMode=yes','root@192.168.10.1','sh'],{input:script,encoding:'utf8',timeout:65000});console.log(r.stdout,r.stderr);assert.equal(r.status,0,'official signed repository staging failed');
}finally{if(started)await call(sid,'gale-connection','disconnect');await call(sid,'session','destroy')}
