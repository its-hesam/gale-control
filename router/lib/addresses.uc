import {mkdtemp,readfile,unlink,rmdir} from 'fs';import {public_ipv4} from '/usr/share/gale/lib/sources.uc';
function hexpart(s){let n=0;for(let i=0;i<length(s);i++)n=n*16+index('0123456789abcdef',substr(s,i,1));return n;}
export function public_ipv6(address){
 if(type(address)!='string'||length(address)>39||!match(address,/^[0-9a-fA-F:]+$/))return false;
 let halves=split(lc(address),'::');if(length(halves)>2)return false;let left=length(halves[0])?split(halves[0],':'):[],right=length(halves)==2&&length(halves[1])?split(halves[1],':'):[];
 for(let x in [...left,...right])if(!match(x,/^[0-9a-f]{1,4}$/))return false;
 if(length(halves)==1&&length(left)!=8)return false;if(length(halves)==2&&length(left)+length(right)>=8)return false;
 let first=length(left)?hexpart(left[0]):0,second=length(left)>1?hexpart(left[1]):0;
 if((first&0xe000)!=0x2000)return false;if(first==0x2002)return false;if(first==0x2001&&(second<0x200||second==0xdb8))return false;return true;
};
export function resolve_public_endpoint(host,family){
 family=family==6||index(host,':')>=0?6:4;let dir=mkdtemp('/tmp/gale-resolve-XXXXXX');if(!dir)die('CONNECTION_DNS_FAILED');let ips=[],error=null;
 try{if(system(['/usr/share/gale/capture',dir+'/dns','/usr/bin/resolveip',family==6?'-6':'-4','-t','3',host],4000)!=0)die('CONNECTION_DNS_FAILED');ips=filter(split(trim(readfile(dir+'/dns')||''),/\s+/),s=>length(s));if(!length(ips)||length(ips)>32)die('CONNECTION_DNS_FAILED');for(let ip in ips)if(!(family==6?public_ipv6(ip):public_ipv4(ip)))die('CONNECTION_PRIVATE_ADDRESS_BLOCKED');}catch(e){error=e.message;}
 unlink(dir+'/dns');rmdir(dir);if(error)die(error);return ips;
};
