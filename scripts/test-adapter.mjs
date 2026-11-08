import {spawnSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
const source=readFileSync('router/gale-status','utf8').replace(/\r/g,'');
for(const args of ['list','call status']){
 const r=spawnSync('ssh',['-o','BatchMode=yes','root@192.168.10.1',`ucode - ${args}`],{input:source,encoding:'utf8'});
 if(r.status!==0){console.error(r.stderr);process.exit(1)}
 const data=JSON.parse(r.stdout);
 if(args==='list'){if(!data.status)throw new Error('No status method')}else{if(data.schema_version!==1||!data.board.model||!data.system.cpu_ticks?.length)throw new Error('Telemetry invalid');console.log(JSON.stringify(data,null,2))}
}
