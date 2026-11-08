import net from 'node:net';
import {spawn,spawnSync} from 'node:child_process';
import {mkdirSync,writeFileSync,readFileSync,existsSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {createHash} from 'node:crypto';
const [id,version]=process.argv.slice(2);
let tunnel=null;const proxyArgs=process.argv.includes('--via-router-proxy')?['--proxy','','--noproxy','','--socks5-hostname','127.0.0.1:18790']:[];
if(proxyArgs.length){
 tunnel=spawn('ssh',['-o','BatchMode=yes','-o','ExitOnForwardFailure=yes','-N','-L','127.0.0.1:18790:127.0.0.1:17890','root@192.168.10.1'],{stdio:'ignore',windowsHide:true});process.on('exit',()=>tunnel?.kill());
 let ready=false;for(let i=0;i<30;i++){if(tunnel.exitCode!==null)throw Error('Temporary SSH forward unavailable');ready=await new Promise(resolve=>{const socket=net.connect(18790,'127.0.0.1');socket.once('connect',()=>{socket.destroy();resolve(true)});socket.once('error',()=>resolve(false))});if(ready)break;await new Promise(r=>setTimeout(r,100));}if(!ready)throw Error('Temporary SSH forward not ready');
}

if(!['xray','sing-box'].includes(id)||!/^\d+\.\d+\.\d+$/.test(version||''))throw Error('Usage: stage-core.mjs xray|sing-box version');
const repo=id==='xray'?'XTLS/Xray-core':'SagerNet/sing-box';
const name=id==='xray'?'Xray-linux-arm32-v7a.zip':`sing-box-${version}-linux-armv7.tar.gz`;
const dir=resolve('.private','core-stage',id,version);mkdirSync(dir,{recursive:true});
let release;
const api='https://api.github.com/repos/'+repo+'/releases/tags/v'+version;
if(process.argv.includes('--curl')){const r=spawnSync('curl.exe',[...proxyArgs,'--ipv4','--fail','--silent','--show-error','--retry','2','--max-time','20','--proto','=https','--header','User-Agent: Gale-Core-Manager',api],{encoding:'utf8',timeout:65000,maxBuffer:2*1024*1024});if(r.status!==0)throw Error('Official release API unavailable');release=JSON.parse(r.stdout);}
else{const response=await fetch(api,{headers:{'User-Agent':'Gale-Core-Manager'},signal:AbortSignal.timeout(20000)});if(!response.ok)throw Error('Official release API: '+response.status);release=await response.json();}
if(release.draft||(release.prerelease&&!process.argv.includes('--allow-prerelease')))throw Error('Prerelease requires --allow-prerelease');
const asset=release.assets.find(a=>a.name===name);
if(!asset||asset.size>67108864||!/^sha256:[0-9a-f]{64}$/.test(asset.digest||''))throw Error('Verified archive digest unavailable');
const expected=`https://github.com/${repo}/releases/download/v${version}/${name}`;
if(asset.browser_download_url!==expected)throw Error('Unexpected upstream URL');
const archive=join(dir,name),digest=b=>createHash('sha256').update(b).digest('hex');
if(!existsSync(archive)||digest(readFileSync(archive))!==asset.digest.slice(7)){
 if(process.argv.includes('--curl')){const r=spawnSync('curl.exe',[...proxyArgs,'--ipv4','--continue-at','-','--fail','--location','--silent','--show-error','--proto','=https','--proto-redir','=https','--max-time',process.argv.includes('--long-download')?'600':'120','--max-filesize',String(asset.size),'--output',archive,expected],{encoding:'utf8',timeout:process.argv.includes('--long-download')?605000:125000});if(r.status!==0)throw Error('Official download failed, curl exit '+r.status+'; retained bytes '+(existsSync(archive)?readFileSync(archive).length:0));if(digest(readFileSync(archive))!==asset.digest.slice(7))throw Error('Archive checksum mismatch');}
 else {const download=await fetch(expected,{signal:AbortSignal.timeout(180000)});if(!download.ok)throw Error(`Download ${download.status}`);
 const chunks=[];let count=0;for await(const chunk of download.body){count+=chunk.length;if(count>asset.size||count>67108864)throw Error('Download size limit');chunks.push(chunk)}
 const buffer=Buffer.concat(chunks);if(buffer.length!==asset.size||digest(buffer)!==asset.digest.slice(7))throw Error('Archive checksum mismatch');writeFileSync(archive,buffer); }
}
const listing=spawnSync('tar',['-tf',archive],{encoding:'utf8'});if(listing.status!==0)throw Error('Archive unreadable');
const binaryName=id==='xray'?'xray':`sing-box-${version}-linux-armv7/sing-box`;
if(!listing.stdout.split(/\r?\n/).includes(binaryName))throw Error('Expected binary absent');
const extract=spawnSync('tar',['-xOf',archive,binaryName],{maxBuffer:100*1024*1024});if(extract.status!==0)throw Error('Binary extraction failed');
const binary=extract.stdout;if(binary[0]!==127||binary.subarray(1,4).toString()!=='ELF'||binary[4]!==1||binary.readUInt16LE(18)!==40)throw Error('Expected ARM ELF32');
const receipt={schema_version:1,id,version,architecture:'linux-armv7',repository:repo,release_url:release.html_url,archive_sha256:asset.digest.slice(7),binary_sha256:digest(binary),verification:'official_github_asset_sha256',signature_verified:false,prerelease:!!release.prerelease,staged_at:Math.floor(Date.now()/1000)};
writeFileSync(join(dir,'core'),binary);writeFileSync(join(dir,'receipt.json'),JSON.stringify(receipt));
const tar=spawnSync('tar',['-czf','-','-C',dir,'core','receipt.json'],{maxBuffer:64*1024*1024});if(tar.status!==0)throw Error('Transfer archive failed');
const target=`/usr/share/gale/managed/${id}/${version}`;
const script=`set -eu; umask 077; test "$(uname -m)" = armv7l; test ! -e '${target}'; mkdir -p '${target}'; tar -xzf - -C '${target}'; cd '${target}'; echo '${receipt.binary_sha256}  core' | sha256sum -c -; chmod 755 core; ./core version >/dev/null; echo 'Staged ${id} ${version}; packaged binary unchanged'`;
const transfer=spawnSync('ssh',['-o','BatchMode=yes','root@192.168.10.1',script],{input:tar.stdout,encoding:'utf8',maxBuffer:1024*1024});if(transfer.status!==0)throw Error(transfer.stderr||transfer.stdout);console.log(transfer.stdout.trim());console.log(JSON.stringify(receipt));

if(tunnel)tunnel.kill();
