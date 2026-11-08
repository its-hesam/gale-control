import {spawnSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
const path=process.argv[2];
if(!path)throw new Error('Script required');
const r=spawnSync('ssh',['-o','BatchMode=yes','root@192.168.10.1','sh'],{input:readFileSync(path,'utf8').replace(/\r/g,''),encoding:'utf8'});
console.log(r.stdout);if(r.status!==0){console.error(r.stderr);process.exit(r.status||1)}
