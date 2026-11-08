import {readfile,writefile,open,mkdtemp,rename,mkdir,stat,chmod,unlink,rmdir} from 'fs';
let root='/tmp/gale-core-update',lock=open(root+'/worker.lock','a',0o600);
if(!lock||!lock.lock('xn'))exit(0);
let job=json(readfile(root+'/job.json')||'{}');if(job.state!='queued')exit(0);
function save(state){job.state=state;job.updated_at=time();writefile(root+'/job.new',sprintf('%J',job));rename(root+'/job.new',root+'/job.json');}
let dir=null;
function run(args,output,timeout){if(system(['/usr/share/gale/capture',output,...args],timeout)!=0)die('CORE_DOWNLOAD_COMMAND_FAILED');}
try{
 if(!(job.id in ['xray','sing-box'])||!match(job.version||'',/^[0-9]+\.[0-9]+\.[0-9]+$/))die('BAD_CORE_REQUEST');
 if(!match(readfile('/etc/openwrt_release')||'',/DISTRIB_ARCH='arm_cortex-a7_neon-vfpv4'/))die('CORE_ARCH_UNSUPPORTED');
 if(system(['/usr/share/gale/core-space'],3000)!=0)die('CORE_STORAGE_BUDGET');
 let repo=job.id=='xray'?'XTLS/Xray-core':'SagerNet/sing-box',name=job.id=='xray'?'Xray-linux-arm32-v7a.zip':'sing-box-'+job.version+'-linux-armv7.tar.gz';
 let target='/usr/share/gale/managed/'+job.id+'/'+job.version;if(stat(target))die('CORE_ALREADY_STAGED');
 dir=mkdtemp('/usr/share/gale/download-XXXXXX');if(!dir)die('CORE_STORAGE_FAILED');chmod(dir,0o700);
 save('metadata');
 run(['/usr/bin/curl','--disable','--fail','--silent','--proxy','','--proto','=https','--max-time','20','--max-filesize','1048576','--user-agent','Gale-Core-Manager','https://api.github.com/repos/'+repo+'/releases/tags/v'+job.version],dir+'/metadata',22000);
 let release=json(readfile(dir+'/metadata')||'{}');if(release.draft||(release.prerelease&&!job.allow_prerelease))die('CORE_PRERELEASE_NOT_ALLOWED');
 let assets=filter(release.assets||[],a=>a.name==name),asset=assets[0];
 if(!asset||asset.size>67108864||!match(asset.digest||'',/^sha256:[0-9a-f]{64}$/))die('OFFICIAL_DIGEST_REQUIRED');
 let url='https://github.com/'+repo+'/releases/download/v'+job.version+'/'+name;if(asset.browser_download_url!=url)die('UNEXPECTED_CORE_URL');
 save('downloading');
 run(['/usr/bin/curl','--disable','--fail','--silent','--proxy','','--location','--proto','=https','--proto-redir','=https','--max-time','180','--max-filesize','67108864',url],dir+'/archive',182000);
 save('verifying');
 run(['/usr/bin/sha256sum',dir+'/archive'],dir+'/hash',5000);let archive_hash=split(trim(readfile(dir+'/hash')||''),/\s+/)[0];if(archive_hash!=substr(asset.digest,7))die('CORE_ARCHIVE_HASH_MISMATCH');
 if(stat(dir+'/archive')?.size!=asset.size)die('CORE_ARCHIVE_SIZE_MISMATCH');
 if(system(['/usr/share/gale/unpack-core',dir,job.id,job.version],30000)!=0)die('CORE_UNPACK_FAILED');
 run(['/usr/bin/sha256sum',dir+'/core'],dir+'/hash',5000);let binary_hash=split(trim(readfile(dir+'/hash')||''),/\s+/)[0];
 if(!match(binary_hash,/^[0-9a-f]{64}$/))die('CORE_BINARY_HASH_FAILED');
 // Never execute an archive until the official archive digest has matched.
 if(system(['/usr/share/gale/check-staged-core',dir,job.id],10000)!=0)die('CORE_HEALTH_CHECK_FAILED');
 let receipt={schema_version:1,id:job.id,version:job.version,architecture:'linux-armv7',repository:repo,release_url:release.html_url,archive_sha256:archive_hash,binary_sha256:binary_hash,verification:'official_github_asset_sha256',signature_verified:false,prerelease:!!release.prerelease,staged_at:time()};
 writefile(dir+'/receipt.json',sprintf('%J',receipt));chmod(dir+'/receipt.json',0o600);
 mkdir('/usr/share/gale/managed');mkdir('/usr/share/gale/managed/'+job.id);
 // Keep staging and final directory on one filesystem for atomic publication.
 for(let f in ['archive','metadata','hash'])unlink(dir+'/'+f);
 if(!rename(dir,target))die('CORE_STAGE_COMMIT_FAILED');dir=null;save('staged');
}catch(e){job.error=match(e.message||'',/^[A-Z0-9_]+$/)?e.message:'CORE_DOWNLOAD_FAILED';save('failed');}
if(dir){for(let f in ['archive','metadata','hash','core','receipt.json'])unlink(dir+'/'+f);rmdir(dir);}
