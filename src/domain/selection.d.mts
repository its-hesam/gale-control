type Candidate={id:string;enabled:boolean;native_status:string;last_test?:{ok:boolean;latency_ms:number|null;tested_at:number}};
export function rankCandidates<T extends Candidate>(profiles:T[],nowSeconds:number):(T&{score:number})[];
export function shouldSwitch(input:{currentId:string;candidateId:string;currentScore:number;candidateScore:number;lastSwitchAt:number;now:number;failures:number;mode:string}):boolean;
