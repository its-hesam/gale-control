import {iran_geoip} from '/usr/share/gale/lib/geoip.uc';import {validate_wifi_rules,smart_firewall} from '/usr/share/gale/lib/smart-policy.uc';import {validate_app_tar} from '/usr/share/gale/lib/app-package.uc';
let passed=0;function reject(fn,expected){let error=null;try{fn();}catch(e){error=e.message;}assert(error==expected,'Expected '+expected+', got '+error);passed++;}
reject(()=>validate_wifi_rules({'6g':'direct'}),'BAD_WIFI_POLICY');reject(()=>validate_wifi_rules({'2g':'exec'}),'BAD_WIFI_POLICY');
reject(()=>smart_firewall({default_action:'vpn',wifi:{'2g':'vpn'},wifi_interfaces:[{band:'2g',device:'bad;device'}]},true,true),'BAD_WIFI_INTERFACE');
reject(()=>iran_geoip(chr(10)+chr(99)),'GEOIP_TRUNCATED');reject(()=>iran_geoip(chr(15)),'GEOIP_BAD_WIRE');
function vi(n){let out='';while(true){let b=n%128;n=int(n/128);out+=chr(b+(n?128:0));if(!n)break;}return out;}
function field(id,s){return vi(id*8+2)+vi(length(s))+s;}
let record=field(1,'IR');for(let n=0;n<10;n++)record+=field(2,field(1,chr(8)+chr(1)+chr(1)+chr(n))+chr(16)+chr(32));
let decoded=iran_geoip(field(1,record));assert(length(decoded.v4)==10&&decoded.v4[9]=='8.1.1.9/32');passed++;
reject(()=>iran_geoip(field(1,field(1,'US')+substr(record,4))),'GEOIP_IR_MISSING_OR_INVALID');
function zeros(n){let s='';for(let i=0;i<n;i++)s+=chr(0);return s;}
function header(name,kind){let h=zeros(512);function put(at,s){h=substr(h,0,at)+s+substr(h,at+length(s));}put(0,name);put(124,'00000000000');put(148,'        ');put(156,kind);let sum=0;for(let i=0;i<512;i++)sum+=ord(h,i);put(148,sprintf('%06o',sum)+chr(0)+' ');return h+zeros(1024);}
reject(()=>validate_app_tar(header('../escape','0')),'APP_TAR_PATH');reject(()=>validate_app_tar(header('symlink','2')),'APP_TAR_ENTRY_TYPE');reject(()=>validate_app_tar(header('SHA256SUMS','0')),'APP_TAR_INCOMPLETE');
print({passed:passed,scope:'policy_input_geoip_parser_and_archive_security'});
