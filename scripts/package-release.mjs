import {readFileSync,readdirSync,mkdirSync,writeFileSync,copyFileSync} from 'node:fs';import {resolve,join} from 'node:path';import {createHash} from 'node:crypto';import {spawnSync} from 'node:child_process';
const hash=b=>createHash('sha256').update(b).digest('hex');
export function packageRelease(){
 const id='r'+new Date().toISOString().replace(/[^0-9]/g,'');const base='/usr/share/gale/releases/'+id,stage=resolve('.private','release-'+id);mkdirSync(stage,{recursive:true});
 const plugins=readdirSync('router').filter(n=>n.startsWith('gale-')&&!n.endsWith('.init')&&!n.endsWith('.json'));
 const services=readdirSync('router').filter(n=>n.endsWith('.init')&&!['gale-release-recovery.init','gale-state-recovery.init'].includes(n)).map(n=>n.slice(0,-5));
 const helpers=readdirSync('router',{withFileTypes:true}).filter(e=>e.isFile()&&!plugins.includes(e.name)&&!e.name.endsWith('.init')&&!e.name.endsWith('.json')&&!['release-recover.uc','state-recover.uc'].includes(e.name)).map(e=>e.name);helpers.push('install-scheduler');
 const files=[],bindings=[];
 const info=Buffer.from(JSON.stringify({id,version:JSON.parse(readFileSync('package.json','utf8')).version,updater_schema:1}));writeFileSync(join(stage,'release-info.json'),info);files.push({path:'release-info.json',mode:644,sha256:hash(info)});
 function add(source,relative,mode=644,rewrite=false){let data=readFileSync(source);if(rewrite){let s=data.toString();s=s.replaceAll('/usr/share/gale/lib/',base+'/lib/').replaceAll('/usr/share/gale/selftests/',base+'/selftests/');for(const name of [...helpers].sort((a,b)=>b.length-a.length))s=s.replaceAll('/usr/share/gale/'+name,base+'/helpers/'+name);for(const name of plugins)s=s.replaceAll('/usr/libexec/rpcd/'+name,base+'/plugins/'+name);data=Buffer.from(s);}mkdirSync(resolve(stage,relative,'..'),{recursive:true});writeFileSync(join(stage,relative),data);files.push({path:relative,mode,sha256:hash(data)});}
 for(const n of readdirSync('router/lib').filter(n=>n.endsWith('.uc')))add('router/lib/'+n,'lib/'+n,644,true);
 for(const n of plugins){add('router/'+n,'plugins/'+n,755,true);bindings.push({destination:'/usr/libexec/rpcd/'+n,relative:'plugins/'+n});}
 for(const n of services){add('router/'+n+'.init','init/'+n,755,true);bindings.push({destination:'/etc/init.d/'+n,relative:'init/'+n});}
 for(const n of helpers){add(n==='install-scheduler'?'scripts/install-scheduler.sh':'router/'+n,'helpers/'+n,n.endsWith('.uc')?644:755,n!=='install-scheduler');bindings.push({destination:'/usr/share/gale/'+n,relative:'helpers/'+n});}
 for(const n of readdirSync('router/selftests'))add('router/selftests/'+n,'selftests/'+n);
 add('router/gale-read.json','acl/gale-read.json');bindings.push({destination:'/usr/share/rpcd/acl.d/gale-read.json',relative:'acl/gale-read.json'});
 function web(dir,relative='web'){for(const e of readdirSync(dir,{withFileTypes:true})){if(e.isDirectory())web(join(dir,e.name),relative+'/'+e.name);else add(join(dir,e.name),relative+'/'+e.name);}}web('dist');writeFileSync(join(stage,'web','.gale-foundation'),'');files.push({path:'web/.gale-foundation',mode:644,sha256:hash(Buffer.alloc(0))});
 for(const [destination,relative] of [['/usr/share/gale/lib','lib'],['/usr/share/gale/selftests','selftests'],['/www/gale','web']])bindings.push({destination,relative,directory:true});
 writeFileSync(join(stage,'bindings.json'),JSON.stringify(bindings));files.push({path:'bindings.json',mode:600,sha256:hash(readFileSync(join(stage,'bindings.json')))});
 const manifest=files.sort((a,b)=>a.path.localeCompare(b.path)).map(f=>`${f.sha256}  ${f.path}\n`).join('');writeFileSync(join(stage,'SHA256SUMS'),manifest);
 const archive=spawnSync('tar',['-czf','-','-C',stage,'.'],{maxBuffer:8*1024*1024});if(archive.status)throw Error('RELEASE_ARCHIVE_FAILED');return {id,base,stage,files,bindings,manifest_hash:hash(manifest),archive:archive.stdout};
}
