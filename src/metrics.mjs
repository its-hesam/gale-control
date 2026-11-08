export function cpuUsage(previous, current) {
 if (!previous || !current || previous.length !== 8 || current.length !== 8) return null;
 const delta=current.map((n,i)=>n-previous[i]);
 if(delta.some(n=>n<0 || !Number.isFinite(n)))return null;
 const total=delta.reduce((a,b)=>a+b,0);
 return total>0 ? Math.max(0,Math.min(100,100*(total-delta[3]-delta[4])/total)) : null;
}
export function rate(previous,current,seconds) {
 return seconds>0 && current>=previous ? (current-previous)/seconds : null;
}
