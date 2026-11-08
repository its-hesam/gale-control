import {spawn,spawnSync} from 'node:child_process';
import {existsSync} from 'node:fs';
import {homedir} from 'node:os';
import {join} from 'node:path';
import {createHash,timingSafeEqual} from 'node:crypto';
import {createInterface} from 'node:readline/promises';
import {StringDecoder} from 'node:string_decoder';
import ssh2 from 'ssh2';const {Client}=ssh2;

export function readSecret(label,{input=process.stdin,output=process.stderr}={}){
 if(!input.isTTY||!output.isTTY)return Promise.reject(Error('Password entry needs an interactive terminal. Run this command directly in PowerShell, Terminal or a TTY; do not pipe a password.'));
 return new Promise((resolve,reject)=>{let value='',finished=false;const raw=!!input.isRaw,decoder=new StringDecoder('utf8');
  function finish(error){if(finished)return;finished=true;input.removeListener('data',data);input.removeListener('error',failed);input.setRawMode(raw);input.pause();output.write('\n');if(error)reject(error);else resolve(value);value='';}
  function failed(){finish(Error('Password entry failed.'));}
  function data(chunk){for(const character of (typeof chunk==='string'?chunk:decoder.write(chunk))){if(character==='\r'||character==='\n'){finish();return;}if(character==='\u0003'||character==='\u0004'){finish(Error('Password entry cancelled.'));return;}if(character==='\u007f'||character==='\b'){if(value){value=Array.from(value).slice(0,-1).join('');output.write('\b \b');}}else if(character==='\u0015'){output.write('\b \b'.repeat(Array.from(value).length));value='';}else if(!/[\u0000-\u001f]/u.test(character)){value+=character;output.write('*');}}}
  output.write(label);input.setRawMode(true);input.resume();input.on('data',data);input.once('error',failed);
 });
}

export function knownHostKeys(host,port=22,files=[join(homedir(),'.ssh','known_hosts'),join(homedir(),'.ssh','known_hosts2'),'/etc/ssh/ssh_known_hosts',...(process.env.ProgramData?[join(process.env.ProgramData,'ssh','ssh_known_hosts')]:[])]){
 const name=port===22?host:`[${host}]:${port}`,keys=[];
 for(const file of files){if(!existsSync(file))continue;const r=spawnSync('ssh-keygen',['-F',name,'-f',file],{encoding:'utf8',timeout:5000});if(r.error)throw Error('OpenSSH ssh-keygen is required to verify the router host key.');if(r.status!==0&&r.status!==1)throw Error('Could not read an SSH known_hosts file. Verify its permissions and format.');
  for(let line of (r.stdout||'').split(/\r?\n/)){if(!line||line.startsWith('#'))continue;let fields=line.trim().split(/\s+/),marker=fields[0].startsWith('@')?fields.shift():null;if(marker==='@cert-authority')continue;const blob=Buffer.from(fields[2]||'','base64');if(blob.length)keys.push({blob,type:fields[1],revoked:marker==='@revoked'});}
 }return keys;
}
export function hostKeyDecision(key,known){
 const matches=known.filter(k=>k.blob.length===key.length&&timingSafeEqual(k.blob,key));
 if(matches.some(k=>k.revoked))return 'revoked';if(matches.length)return 'trusted';return known.length?'changed':'unknown';
}
async function confirmHost(target,key,{input=process.stdin,output=process.stderr}={}){
 const fingerprint='SHA256:'+createHash('sha256').update(key).digest('base64').replace(/=+$/,'');
 if(!input.isTTY||!output.isTTY)throw Error(`SSH host key for ${target} is not trusted. Run ssh ${target} in a terminal to verify it first.`);
 const reader=createInterface({input,output});try{return (await reader.question(`New SSH host ${target}\nFingerprint ${fingerprint}\nVerify this fingerprint with your router. Trust it for this installation? Type yes: `)).trim()==='yes';}finally{reader.close();}
}
function nativeConfig(target){
 const r=spawnSync('ssh',['-G',target],{encoding:'utf8',timeout:10000});if(r.error)throw Error('OpenSSH is required. Install the OpenSSH client and retry.');if(r.status!==0)throw Error('Could not read SSH client configuration.');
 const result={};for(const line of r.stdout.split(/\r?\n/)){const at=line.indexOf(' ');if(at>0)result[line.slice(0,at)]=line.slice(at+1).trim();}return result;
}
function nativeTransport(target){
 return {mode:'openssh',async exec(command,input,timeout=60000){const r=spawnSync('ssh',['-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','-o','ConnectTimeout=5',target,command],{input,encoding:Buffer.isBuffer(input)?undefined:'utf8',timeout,maxBuffer:8*1024*1024});if(r.status!==0)throw Error(r.error?.code==='ETIMEDOUT'?'SSH command timed out.':r.stderr?.toString().trim()||'SSH command failed.');return r.stdout.toString();},
  async hold(command){const child=spawn('ssh',['-o','BatchMode=yes','-o','StrictHostKeyChecking=yes',target,command],{stdio:['pipe','pipe','pipe']});return await holdChannel(child.stdout,child.stdin,child,'exit',()=>child.kill());},async close(){}};
}
async function holdChannel(stdout,stdin,events,event,abort){
 let released=false;
 await new Promise((resolve,reject)=>{let text='';const timer=setTimeout(()=>{abort();reject(Error('Release lock timed out.'));},10000);function failed(){clearTimeout(timer);reject(Error('Release lock unavailable.'));}events.once(event,failed);events.once('error',failed);stdout.on('data',chunk=>{text+=chunk.toString();if(text.includes('LOCKED\n')){clearTimeout(timer);events.removeListener(event,failed);events.removeListener('error',failed);resolve();}});});
 return {async release(){if(released)return;released=true;await new Promise(resolve=>{let timer=setTimeout(()=>{abort();resolve();},5000);events.once(event,()=>{clearTimeout(timer);resolve();});stdin.end();});}};
}

export async function connectSSH(target,{auth='auto',port,knownHostsFiles,passwordPrompt=label=>readSecret(label),hostPrompt=(name,key)=>confirmHost(name,key),useConfig=true}={}){
 if(!/^root@[A-Za-z0-9][A-Za-z0-9.-]*$/.test(target))throw Error('Use --host root@hostname or root@IPv4');
 if(!['auto','password','batch'].includes(auth))throw Error('Invalid SSH authentication mode.');
 if(auth!=='password'){
  const r=spawnSync('ssh',['-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','-o','ConnectTimeout=5',target,'true'],{encoding:'utf8',timeout:15000});
  if(r.status===0)return nativeTransport(target);
  const message=r.stderr||r.stdout||'';if(auth==='batch'||!/Permission denied|Authentication failed|Too many authentication failures|Host key verification failed/i.test(message)||/REMOTE HOST IDENTIFICATION HAS CHANGED/i.test(message))throw Error(message.trim()||'SSH connection failed. Check the host, network and OpenSSH installation.');
  console.error('SSH key/agent login was unavailable. Switching to interactive password authentication.');
 }
 const config=useConfig?nativeConfig(target):{},host=config.hostname||target.slice(5),sshPort=port??Number(config.port||22);
 if(!Number.isInteger(sshPort)||sshPort<1||sshPort>65535)throw Error('Invalid SSH port.');
 if(config.proxycommand&&config.proxycommand!=='none'||config.proxyjump&&config.proxyjump!=='none')throw Error('Password fallback currently needs a direct SSH connection. For ProxyJump/ProxyCommand use SSH key authentication.');
 const configuredFiles=config.userknownhostsfile?.match(/"[^"]+"|\S+/g)?.map(p=>p.replace(/^"|"$/g,'').replace(/^~(?=[/\\])/,homedir()));
 const defaultFiles=[join(homedir(),'.ssh','known_hosts'),join(homedir(),'.ssh','known_hosts2'),'/etc/ssh/ssh_known_hosts',...(process.env.ProgramData?[join(process.env.ProgramData,'ssh','ssh_known_hosts')]:[])];
 const known=knownHostKeys(config.hostkeyalias&&config.hostkeyalias!=='none'?config.hostkeyalias:host,sshPort,knownHostsFiles??[...new Set([...defaultFiles,...(configuredFiles||[])])]);
 const client=new Client();let reason='',attempts=0,first=true,closed=false;client.once('close',()=>{closed=true;});
 const preference=[...new Set(known.filter(k=>!k.revoked).flatMap(k=>k.type==='ssh-rsa'?['rsa-sha2-512','rsa-sha2-256']:[k.type]))];
 await new Promise((resolve,reject)=>{
  const socketTimer=setTimeout(()=>{reason='SSH connection timed out. Check the router address and network.';client.destroy();reject(Error(reason));},10000);
  client.once('connect',()=>clearTimeout(socketTimer));client.once('ready',()=>{clearTimeout(socketTimer);resolve();});client.once('close',()=>{clearTimeout(socketTimer);reject(Error(reason||'SSH connection closed before authentication.'));});client.on('error',error=>{clearTimeout(socketTimer);reason=reason||(/authentication methods failed/i.test(error.message)?'SSH password authentication failed. Check the root password and whether password login is enabled.':error.message);reject(Error(reason));});
  client.connect({host,port:sshPort,username:'root',readyTimeout:300000,keepaliveInterval:15000,keepaliveCountMax:3,
   ...(preference.length?{algorithms:{serverHostKey:{prepend:preference}}}:{}),
   hostVerifier(key,done){const decision=hostKeyDecision(key,known);if(decision==='trusted'){done(true);return;}if(decision!=='unknown'){reason=`SSH host key is ${decision} for ${target}. Verify the router identity and correct known_hosts before retrying.`;done(false);return;}Promise.resolve(hostPrompt(target,key)).then(accepted=>{if(!accepted)reason='SSH host key was not approved.';else known.push({blob:Buffer.from(key),type:'',revoked:false});done(accepted);},error=>{reason=error.message;done(false);});},
   authHandler(methods,partial,done){if(first){first=false;done({type:'none',username:'root'});return;}if(!methods?.includes('password')||attempts>=3){done(false);return;}attempts++;Promise.resolve(passwordPrompt(`SSH password for ${target}${attempts>1?' (retry '+attempts+'/3)':''}: `)).then(password=>done({type:'password',username:'root',password}),error=>{reason=error.message;done(false);});}
  });
 }).catch(error=>{client.destroy();throw error;});
 return {mode:'password',async exec(command,input,timeout=60000){return await new Promise((resolve,reject)=>{let timer;client.exec(command,(error,stream)=>{if(error){reject(Error('SSH channel could not open: '+error.message));return;}let stdout=[],stderr=[],bytes=0,settled=false;function fail(message){if(settled)return;settled=true;clearTimeout(timer);stream.close();reject(Error(message));}timer=setTimeout(()=>fail('SSH command timed out.'),timeout);stream.on('data',chunk=>{bytes+=chunk.length;if(bytes>8*1024*1024)fail('SSH output exceeded the limit.');else stdout.push(chunk);});stream.stderr.on('data',chunk=>{bytes+=chunk.length;if(bytes>8*1024*1024)fail('SSH output exceeded the limit.');else stderr.push(chunk);});stream.once('error',()=>fail('SSH command channel failed.'));stream.once('close',code=>{if(settled)return;settled=true;clearTimeout(timer);if(code!==0)reject(Error(Buffer.concat(stderr).toString().trim()||'SSH command failed (exit '+code+').'));else resolve(Buffer.concat(stdout).toString());});stream.end(input??'');});});},
  async hold(command){const stream=await new Promise((resolve,reject)=>client.exec(command,(error,channel)=>error?reject(error):resolve(channel)));return await holdChannel(stream,stream,stream,'close',()=>stream.close());},
  async close(){if(closed)return;await new Promise(resolve=>{const timer=setTimeout(()=>{client.destroy();resolve();},2000);client.once('close',()=>{clearTimeout(timer);resolve();});client.end();});}
 };
}
