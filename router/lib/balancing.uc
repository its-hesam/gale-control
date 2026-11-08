export function balanced_dispatcher(count){
 if(count!=2)die('BALANCED_POOL_REQUIRES_TWO');
 let outbounds=[];for(let i=1;i<=count;i++)push(outbounds,{tag:'member-'+i,protocol:'socks',settings:{servers:[{address:'127.0.0.1',port:17900+i}]}});
 push(outbounds,{tag:'unavailable',protocol:'blackhole',settings:{}});
 return {log:{loglevel:'none'},stats:{},policy:{system:{statsOutboundUplink:true,statsOutboundDownlink:true}},api:{tag:'gale-api',services:['StatsService']},inbounds:[{tag:'local-proxy',listen:'127.0.0.1',port:17890,protocol:'socks',settings:{auth:'noauth',udp:true}},{tag:'api',listen:'127.0.0.1',port:17894,protocol:'dokodemo-door',settings:{address:'127.0.0.1'}}],outbounds:outbounds,
 routing:{domainStrategy:'AsIs',rules:[{type:'field',inboundTag:['api'],outboundTag:'gale-api'},{type:'field',inboundTag:['local-proxy'],balancerTag:'balanced'}],balancers:[{tag:'balanced',selector:['member-'],fallbackTag:'unavailable',strategy:{type:'roundRobin'}}]},
 observatory:{subjectSelector:['member-'],probeURL:'https://www.gstatic.com/generate_204',probeInterval:'60s',enableConcurrency:false}};
};
