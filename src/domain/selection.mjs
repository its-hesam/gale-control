// No invented bandwidth/loss metrics. Rank only fresh measured successes.
export function rankCandidates(profiles, nowSeconds) {
 return profiles.filter(p=>p.enabled && p.native_status==='passed' && p.last_test?.ok && Number.isFinite(p.last_test.latency_ms) && p.last_test.latency_ms>=0 && nowSeconds-p.last_test.tested_at>=0 && nowSeconds-p.last_test.tested_at<=900)
 .map(p=>({...p,score:1000/(1+p.last_test.latency_ms)}))
 .sort((a,b)=>b.score-a.score || a.id.localeCompare(b.id));
}
export function shouldSwitch({currentId, candidateId, currentScore, candidateScore, lastSwitchAt, now, failures, mode}) {
 if(mode==='manual'||!candidateId||currentId===candidateId)return false;
 if(now-lastSwitchAt<120)return false;
 if(failures>=3)return true;
 if(mode==='failover')return false;
 return mode==='best' && candidateScore>currentScore*1.2;
}
