import {spawnSync} from 'node:child_process';
import {mkdirSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const dir='.private/backup-'+new Date().toISOString().replace(/[:.]/g,'-');
mkdirSync(dir,{recursive:true});
const who=spawnSync('whoami',[],{encoding:'utf8'}).stdout.trim();
const acl=spawnSync('icacls',['.private','/inheritance:r','/grant:r',`${who}:(OI)(CI)F`],{encoding:'utf8'});
if(acl.status!==0) throw new Error('Could not restrict backup directory');
// Archive travels over SSH stdout directly into memory/file; no remote file needed.
const r=spawnSync('ssh',['-o','BatchMode=yes','-o','ConnectTimeout=8','root@192.168.10.1','tar -czf - /etc /usr/share/rpcd/acl.d /www/index.html'],{maxBuffer:32*1024*1024});
if(r.status!==0)throw new Error('Backup failed');
writeFileSync(`${dir}/config.tgz`,r.stdout);
const hash=createHash('sha256').update(r.stdout).digest('hex');
writeFileSync(`${dir}/sha256.txt`,hash+'  config.tgz\n');
const check=spawnSync('tar',['-tzf',`${dir}/config.tgz`],{encoding:'utf8'});
if(check.status!==0)throw new Error('Archive listing failed');
writeFileSync(`${dir}/files.txt`,check.stdout);
console.log(JSON.stringify({backup:dir,bytes:r.stdout.length,sha256:hash,entries:check.stdout.trim().split('\n').length,restoreTested:false}));
