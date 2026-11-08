import {packageRelease} from './package-release.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const p=packageRelease();mkdirSync('.private/github-release',{recursive:true});
writeFileSync('.private/github-release/gale-control.tar.gz',p.archive);
writeFileSync('.private/github-release/SHA256SUMS',createHash('sha256').update(p.archive).digest('hex')+'  gale-control.tar.gz\n');
console.log(JSON.stringify({id:p.id,files:p.files.length,bytes:p.archive.length}));
