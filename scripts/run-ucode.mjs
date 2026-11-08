import {spawnSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
const r=spawnSync('ssh',['-o','BatchMode=yes','root@192.168.10.1',`ucode - ${process.argv.slice(3).join(' ')}`],{input:readFileSync(process.argv[2],'utf8').replace(/\r/g,''),encoding:'utf8',maxBuffer:2*1024*1024});
console.log(r.stdout);if(r.status!==0){console.error(r.stderr);process.exit(1)}
