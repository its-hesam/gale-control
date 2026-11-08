import { mkdtemp, writefile, readfile, stat, unlink, rmdir } from 'fs';
import { sha256 } from 'digest';
export function validate_user_agent(value) {
 if (type(value)!='string' || length(value)>256 || match(value,/[^ -~]/)) die('BAD_USER_AGENT');
 return value;
};
export function source_url(url) {
 if (type(url)!='string' || length(url)>4096 || match(url,/[[:cntrl:][:space:]"]/) || index(url,'\\')>=0) die('BAD_SOURCE_URL');
 let parts=match(url,/^https:\/\/([^\/?#]+)([^#]*)$/);
 if (!parts) die('HTTPS_REQUIRED_NO_FRAGMENT');
 let hostport=match(parts[1],/^([a-zA-Z0-9][a-zA-Z0-9.-]*)(:([0-9]+))?$/);
 if (!hostport || length(hostport[1])>253) die('BAD_SOURCE_HOST');
 let host=lc(hostport[1]),port=hostport[3] ? +hostport[3] : 443;
 if (port<1 || port>65535 || match(host,/(^|\.)(localhost|local|lan|internal)$/)) die('SOURCE_HOST_BLOCKED');
 return {url:url,host:host,port:port,id:sha256(url)};
};
export function public_ipv4(ip) {
 let octets=split(ip,'.');
 if (length(octets)!=4) return false;
 for (let v in octets) if (!match(v,/^(0|[1-9][0-9]*)$/) || +v>255) return false;
 let a=+octets[0],b=+octets[1],c=+octets[2];
 if (a==0 || a==10 || a==127 || a>=224 || (a==100 && b>=64 && b<=127) || (a==169 && b==254) || (a==172 && b>=16 && b<=31)) return false;
 if (a==192 && (b==168 || (b==0 && (c==0 || c==2)) || (b==88 && c==99))) return false;
 if ((a==198 && (b==18 || b==19 || (b==51 && c==100))) || (a==203 && b==0 && c==113)) return false;
 return true;
};
export function fetch_source(url, user_agent) {
 if (user_agent==null) user_agent='';
 validate_user_agent(user_agent);
 let info=source_url(url),temp=mkdtemp('/tmp/gale-fetch-XXXXXX');
 if (!temp) die('FETCH_STORAGE_FAILED');
 let outcome=null,failure=null;
 try {
  let dns=system(['/usr/share/gale/capture',temp+'/dns','/usr/bin/resolveip','-4','-t','3',info.host],4000);
  if (dns!=0) die('SOURCE_DNS_FAILED');
  let ips=filter(split(trim(readfile(temp+'/dns') || ''),/\s+/),v=>length(v));
  if (!length(ips)) die('SOURCE_NO_IPV4');
  for (let ip in ips) if (!public_ipv4(ip)) die('SOURCE_PRIVATE_ADDRESS_BLOCKED');
  // Pin DNS to the validated public address. No redirect is followed, and proxy env is disabled.
  if (!writefile(temp+'/curl.conf','url = '+sprintf('%J',url)+'\n')) die('FETCH_STORAGE_FAILED');
  let args=['/usr/share/gale/capture',temp+'/status','/usr/bin/curl','--disable','--config',temp+'/curl.conf','--silent','--show-error','--fail','--ipv4','--proxy','','--noproxy','*','--proto','=https','--max-redirs','0','--connect-timeout','4','--max-time','10','--max-filesize','1048576','--resolve',info.host+':'+info.port+':'+ips[0],'--output',temp+'/body','--write-out','%{http_code}'];
  if (length(user_agent)) {push(args,'--user-agent');push(args,user_agent);}
  let code=system(args,12000);
  if (code!=0) die('SOURCE_FETCH_FAILED');
  let status=trim(readfile(temp+'/status') || '');
  if (status!='200') die('SOURCE_HTTP_'+status);
  let size=stat(temp+'/body')?.size;
  if (!size || size>1048576) die('SOURCE_SIZE');
  outcome=readfile(temp+'/body');
 } catch(e) {failure=e.message;}
 for (let file in ['dns','curl.conf','status','body']) unlink(temp+'/'+file);
 rmdir(temp);
 if (failure) die(failure);
 return outcome;
};
