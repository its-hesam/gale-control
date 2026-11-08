import {core_config,validate_core} from '/usr/share/gale/lib/adapter.uc';
import {core_path} from '/usr/share/gale/lib/cores.uc';
import {pin_target} from '/usr/share/gale/lib/dial.uc';
import {parse_profile} from '/usr/share/gale/lib/profiles.uc';
import {writefile,readfile,mkdtemp,chmod,unlink,rmdir,lsdir} from 'fs';
let results=[];
for(let test in [{transport:'grpc',tls:false},{transport:'xhttp',tls:false},{transport:'grpc',tls:true},{transport:'xhttp',tls:true}]){let transport=test.transport;
 let dir=mkdtemp('/tmp/gale-transport-XXXXXX');chmod(dir,0o700);
 let uuid='00000000-0000-4000-8000-000000000001';
 let model={protocol:'vmess',endpoint:{host:'gale-fixture.invalid',port:18881},credentials:{id:uuid},transport:transport,security:'none',parameters:{net:transport,path:transport=='grpc'?'gale-fixture':'/gale-fixture',type:'none'}};
 if(test.tls){model.security='tls';model.parameters.allowInsecure='1';model.parameters.sni='gale-fixture.invalid';}
 let profile={model:model,tls_mode:test.tls?'insecure':'strict'},selected=core_config(profile,{allow_insecure:false});pin_target(selected,profile,'127.0.0.1');
 if(transport=='grpc')assert(selected.config.outbounds[0].streamSettings.grpcSettings.authority=='gale-fixture.invalid','authority lost');
 selected.config.inbounds=[{listen:'127.0.0.1',port:18882,protocol:'socks',settings:{auth:'noauth'}}];
 let stream=transport=='grpc'?{network:'grpc',grpcSettings:{serviceName:'gale-fixture'}}:{network:'xhttp',xhttpSettings:{path:'/gale-fixture'}};
 if(test.tls){if(system(['/usr/share/gale/capture',dir+'/cert.json',core_path('xray'),'tls','cert','--domain=gale-fixture.invalid'],5000)!=0)die('FIXTURE_CERT_FAILED');let cert=json(readfile(dir+'/cert.json'));stream.security='tls';stream.tlsSettings={certificates:[cert]};}
 selected.config.log={loglevel:'debug'};let server={log:{loglevel:'debug'},inbounds:[{listen:'127.0.0.1',port:18881,protocol:'vmess',settings:{clients:[{id:uuid,alterId:0}]},streamSettings:stream}],outbounds:[{protocol:'freedom',settings:{finalRules:[{action:'allow',ip:['127.0.0.1/32'],port:'80'}]}}]};
 for(let role in ['server','client']){writefile(dir+'/'+role+'.json',sprintf('%J',role=='server'?server:selected.config));writefile(dir+'/'+role+'-binary',(role=='client'?(selected.binary||core_path('xray')):core_path('xray'))+'\n');}
 let code=system(['/usr/share/gale/transport-pair-test',dir],15000);if(code!=0)print({fixture_transport:transport,server_log:readfile(dir+'/server.log'),client_log:readfile(dir+'/client.log')});push(results,{transport:transport,self_signed_tls:test.tls,compatibility_version:selected.compatibility_version||null,pinned_address:true,local_real_proxy_roundtrip:code==0,exit_code:code,scope:'loopback_fixture_no_provider_handshake'});
 for(let file in lsdir(dir)||[])unlink(dir+'/'+file);rmdir(dir);
}
print({results:results});
for(let result in results)assert(result.local_real_proxy_roundtrip,'transport integration failed');
