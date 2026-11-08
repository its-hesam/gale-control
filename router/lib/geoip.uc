// Bounded protobuf decoder for v2fly GeoIPList; retain only country IR.
function varint(s,p){let n=0,m=1;for(let i=0;i<6;i++){if(p.at>=length(s))die('GEOIP_TRUNCATED');let b=ord(s,p.at++);n+=(b&127)*m;if(!(b&128))return n;m*=128;}die('GEOIP_BAD_VARINT');}
function fields(s){let p={at:0},out=[];while(p.at<length(s)){let key=varint(s,p),wire=key&7,id=key>>3;if(id<1)die('GEOIP_BAD_FIELD');let value;
 if(wire==0)value=varint(s,p);else if(wire==2){let size=varint(s,p);if(size>length(s)-p.at)die('GEOIP_TRUNCATED');value=substr(s,p.at,size);p.at+=size;}else if(wire==1||wire==5){p.at+=wire==1?8:4;if(p.at>length(s))die('GEOIP_TRUNCATED');continue;}else die('GEOIP_BAD_WIRE');push(out,{id:id,wire:wire,value:value});if(length(out)>20000)die('GEOIP_FIELD_LIMIT');}return out;}
export function iran_geoip(data){
 if(length(data)>1048576)die('GEOIP_TOO_LARGE');let result={v4:[],v6:[]},found=false;
 for(let outer in fields(data)){if(outer.id!=1||outer.wire!=2)continue;let record=fields(outer.value),country=filter(record,f=>f.id==1&&f.wire==2)[0]?.value;if(uc(country||'')!='IR')continue;if(found)die('GEOIP_DUPLICATE_IR');found=true;
  if(filter(record,f=>f.id==3&&f.value!=0)[0])die('GEOIP_INVERSE_UNSUPPORTED');
  for(let field in record){if(field.id!=2||field.wire!=2)continue;let cidr=fields(field.value),ip=filter(cidr,f=>f.id==1&&f.wire==2)[0]?.value,prefix=filter(cidr,f=>f.id==2&&f.wire==0)[0]?.value||0,bytes=length(ip||'');if(!(bytes in [4,16])||prefix<0||prefix>bytes*8)die('GEOIP_BAD_CIDR');let parts=[];
   if(bytes==4){for(let i=0;i<4;i++)push(parts,''+ord(ip,i));push(result.v4,join('.',parts)+'/'+prefix);}else{for(let i=0;i<16;i+=2)push(parts,sprintf('%x',ord(ip,i)*256+ord(ip,i+1)));push(result.v6,join(':',parts)+'/'+prefix);}
  }
 }if(!found||length(result.v4)<10||length(result.v4)+length(result.v6)>20000)die('GEOIP_IR_MISSING_OR_INVALID');return result;
};
