import {readfile} from 'fs';
function octal(s){s=trim(replace(s,/\x00/g,''));if(!match(s,/^[0-7]*$/))die('APP_TAR_BAD_NUMBER');let n=0;for(let i=0;i<length(s);i++)n=n*8+ord(s,i)-48;return n;}
// No symlinks, hardlinks, devices, PAX overrides, absolute paths or traversal.
export function validate_app_tar(data){
 if(length(data)>16777216||length(data)%512)die('APP_TAR_SIZE');let seen={},count=0,zero=0;
 for(let at=0;at<length(data);){let h=substr(data,at,512);if(ord(h,0)==0){zero++;at+=512;continue;}if(zero)die('APP_TAR_TRAILING_DATA');
  let expected=octal(substr(h,148,8)),sum=0;for(let i=0;i<512;i++)sum+=(i>=148&&i<156)?32:ord(h,i);if(expected!=sum)die('APP_TAR_CHECKSUM');
  let name=split(substr(h,0,100),'\x00')[0],prefix=split(substr(h,345,155),'\x00')[0];if(length(prefix))name=prefix+'/'+name;name=replace(name,/^\.\//,'');
  let kind=substr(h,156,1),size=octal(substr(h,124,12));if(!(kind in ['0','\x00','5']))die('APP_TAR_ENTRY_TYPE');if(kind=='5'&&size)die('APP_TAR_DIRECTORY_SIZE');
  if(name!=''&&(!match(name,/^[A-Za-z0-9_./-]+$/)||substr(name,0,1)=='/'||index(split(name,'/'),'..')>=0||index(split(name,'/'),'.')>=0))die('APP_TAR_PATH');
  if(name!=''){if(seen[name])die('APP_TAR_DUPLICATE');seen[name]=true;}if(++count>600||size>8388608||at+512+size>length(data))die('APP_TAR_ENTRY_SIZE');at+=512+int((size+511)/512)*512;
 }if(zero<2||!seen['SHA256SUMS']||!seen['bindings.json']||!seen['release-info.json'])die('APP_TAR_INCOMPLETE');return count;
};
export function validate_app_bindings(bindings,base){
 if(type(bindings)!='array'||length(bindings)>250)die('APP_BINDINGS_INVALID');let seen={};
 for(let b in bindings){if(type(b.relative)!='string'||!match(b.relative,/^[A-Za-z0-9_.\/-]+$/)||index(split(b.relative,'/'),'..')>=0||seen[b.destination])die('APP_BINDING_PATH');seen[b.destination]=true;
  let expected=b.relative=='web'?'/www/gale':b.relative=='lib'?'/usr/share/gale/lib':b.relative=='selftests'?'/usr/share/gale/selftests':b.relative=='acl/gale-read.json'?'/usr/share/rpcd/acl.d/gale-read.json':match(b.relative,/^plugins\/gale-[a-z-]+$/)?'/usr/libexec/rpcd/'+substr(b.relative,8):match(b.relative,/^init\/gale-[a-z-]+$/)?'/etc/init.d/'+substr(b.relative,5):match(b.relative,/^helpers\/[a-zA-Z0-9_.-]+$/)?'/usr/share/gale/'+substr(b.relative,8):null;
  if(!expected||expected!=b.destination||!readfile(base+'/SHA256SUMS'))die('APP_BINDING_DESTINATION');
 }return true;
};
