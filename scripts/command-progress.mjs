export function duration(ms){const seconds=Math.floor(ms/1000);return `${Math.floor(seconds/60)}:${String(seconds%60).padStart(2,'0')}`;}
export async function runStage(transport,{label,script,timeout=300000,heartbeatMs=15000,write=chunk=>process.stdout.write(chunk),now=Date.now}){
 const started=now();let lastOutput=started,streamed=false;const chunks=[];
 write(`\n[${label}] Started | time limit ${duration(timeout)} | remaining time is unknown\n`);
 const timer=setInterval(()=>write(`\n[${label}] Still waiting | elapsed ${duration(now()-started)} | no output for ${duration(now()-lastOutput)} | limit ${duration(timeout)}\n`),heartbeatMs);
 const output=chunk=>{streamed=true;lastOutput=now();chunks.push(Buffer.from(chunk));write(chunk);};
 try{
  const result=await transport.exec('sh',script,timeout,{onStdout:output,onStderr:output});
  if(!streamed&&result)write(result); // Compatible with transports without streaming support.
  write(`\n[${label}] Completed in ${duration(now()-started)}\n`);return result;
 }catch(error){
  const elapsed=duration(now()-started);
  if(/timed out/i.test(error.message))throw Error(`[${label}] Timed out after ${elapsed} (limit ${duration(timeout)}). No firmware flash was started by this preparation stage. The remote build may still be running; inspect it before retrying.\n${error.message}`);
  const diagnostic=Buffer.concat(chunks).toString();
  throw Error(`[${label}] Failed after ${elapsed}.\n${diagnostic}${diagnostic.includes(error.message)?'':'\n'+error.message}`);
 }finally{clearInterval(timer);}
}
