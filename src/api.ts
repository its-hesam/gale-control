export type Telemetry={schema_version:number;network_trial?:boolean;observed_at:number;board:{model:string;release:string;kernel:string;target:string};system:{uptime:number;memory:{total:number;available:number};root:{total:number;free:number};load:number[];cpu_ticks:number[]};wan:{up:boolean;device:string;proto:string;addresses?:{address:string;mask:number}[];dns?:string[]};interfaces:{name:string;rx_bytes:number;tx_bytes:number;state:string}[];services:{name:string;registered:boolean;instances:{name:string;running:boolean;exit_code?:number|null}[]}[];limitations:string[]};
let serial=0;
export class RpcError extends Error{constructor(public code:number){super(`RPC ${code}`)}}
export async function rpc<T>(sid:string,object:string,method:string,args:Record<string,unknown>={},timeoutMs=8000):Promise<T>{
 const response=await fetch('/ubus',{method:'POST',headers:{'Content-Type':'application/json'},credentials:'omit',cache:'no-store',signal:AbortSignal.timeout(timeoutMs),body:JSON.stringify({jsonrpc:'2.0',id:++serial,method:'call',params:[sid,object,method,args]})});
 if(!response.ok)throw new Error(`HTTP ${response.status}`);
 const body=await response.json();
 if(body.error)throw new RpcError(body.error.code);
 if(!Array.isArray(body.result)||body.result[0]!==0)throw new RpcError(body.result?.[0]??-1);
 if(body.result[1]?.error)throw new Error(String(body.result[1].error));
 return body.result[1] as T;
}
export async function login(password:string){return rpc<{ubus_rpc_session:string}>('00000000000000000000000000000000','session','login',{username:'root',password,timeout:900})}

export async function uploadProfileText(sid:string,content:string){const bytes=new TextEncoder().encode(content);if(bytes.length>1048576)throw new Error('PROFILE_UPLOAD_LIMIT');const upload=await rpc<{token:string;chunk_bytes:number}>(sid,'gale-backup','upload_begin',{bytes:bytes.length,target:'profiles'});for(let offset=0;offset<bytes.length;offset+=upload.chunk_bytes){const chunk=bytes.slice(offset,offset+upload.chunk_bytes);await rpc(sid,'gale-backup','upload_chunk',{token:upload.token,offset,data:btoa(Array.from(chunk,b=>String.fromCharCode(b)).join(''))})}return upload.token;}
