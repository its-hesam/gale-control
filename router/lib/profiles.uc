import {yaml_document,clash_profiles} from '/usr/share/gale/lib/formats.uc';
import {native_json_models} from '/usr/share/gale/lib/native-json.uc';
import { urldecode } from 'lucihttp';
import { sha256 } from 'digest';
import {parse_wireguard} from '/usr/share/gale/lib/wireguard.uc';
import {parse_openvpn} from '/usr/share/gale/lib/openvpn.uc';

function require_value(ok, code) { if (!ok) die(code); }
function decode(value) {
 require_value(index(replace(value, /%[0-9a-fA-F]{2}/g, ''),'%') < 0, 'BAD_PERCENT_ENCODING');
 let result = urldecode(value, 0);
 require_value(!match(result, /[[:cntrl:]]/), 'CONTROL_CHARACTER');
 return result;
};
function base64(value) {
 let encoded = replace(replace(value, /-/g, '+'), /_/g, '/');
 while (length(encoded) % 4) encoded += '=';
 let result = b64dec(encoded);
 require_value(type(result) == 'string', 'BAD_BASE64');
 return result;
};
function endpoint(host, port) {
 require_value(type(host) == 'string' && length(host) <= 253 && (!!match(host, /^[a-zA-Z0-9][a-zA-Z0-9.-]*$/) || !!match(host, /^[0-9a-fA-F:]+$/)), 'BAD_HOST');
 require_value(type(port) in ['string','int'] && !!match(''+port, /^[0-9]+$/) && +port > 0 && +port <= 65535, 'BAD_PORT');
 return {host:lc(host),port:+port};
};
function uri(raw) {
 let scheme = match(raw, /^([a-z0-9]+):\/\/(.*)$/);
 require_value(!!scheme, 'UNKNOWN_FORMAT');
 let protocol = scheme[1], payload = scheme[2];
 if (protocol == 'hy2') protocol = 'hysteria2';
 require_value(protocol in ['vless','vmess','trojan','ss','socks5','http','https','hysteria2','tuic','anytls','ssh'], 'UNKNOWN_PROTOCOL');
 if (protocol == 'vmess') {
  let fields; try { fields = json(base64(split(payload,'#')[0])); } catch(e) { die('BAD_VMESS_JSON'); }
  require_value(type(fields) == 'object', 'BAD_VMESS_JSON');
  require_value(type(fields.id) == 'string' && !!match(fields.id,/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/), 'BAD_UUID');
  return {protocol:protocol,endpoint:endpoint(fields.add,fields.port),credentials:{id:fields.id},transport:fields.net || 'tcp',security:fields.tls || 'none',parameters:fields,name:substr(fields.ps || 'VMess',0,100)};
 }
 if (protocol == 'ss' && index(payload,'@') < 0) {let encoded=split(payload,'#');payload=base64(encoded[0])+(length(encoded)>1 ? '#'+encoded[1] : '');}
 let fragment=index(payload,'#');
 let label=fragment<0 ? '' : substr(payload,fragment+1);
 if (fragment>=0) payload=substr(payload,0,fragment);
 let question=index(payload,'?');
 let parts=[null,question<0 ? payload : substr(payload,0,question),question<0 ? '' : substr(payload,question+1),label];
 require_value(length(parts[1])>0, 'BAD_URI');
 let authority = replace(parts[1], /\/$/, '');
 let auth = match(authority, /^(.*)@([^@]+)$/);
 let hostport = auth ? auth[2] : authority;
 let hp = match(hostport, /^\[([0-9a-fA-F:]+)\]:([0-9]+)$/) || match(hostport, /^([^:/]+):([0-9]+)$/);
 if (!hp && protocol in ['http','https']) hp = [hostport,hostport,protocol == 'https' ? '443' : '80'];
 require_value(!!hp, 'HOST_AND_PORT_REQUIRED');
 let parameters = {};
 for (let pair in split(parts[2] || '', '&')) {
  if (!length(pair)) continue;
  let eq = index(pair,'=');
  let key = decode(eq < 0 ? pair : substr(pair,0,eq));
  let value = decode(eq < 0 ? '' : substr(pair,eq+1));
  require_value(length(key) <= 100 && !exists(parameters,key), 'DUPLICATE_OR_LONG_PARAMETER');
  parameters[key] = value;
 }
 let credentials = auth ? decode(auth[1]) : '';
 if (protocol == 'vless') require_value(!!match(credentials,/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/), 'BAD_UUID');
 if (!(protocol in ['http','https','socks5'])) require_value(length(credentials) > 0, 'CREDENTIAL_REQUIRED');
 if (protocol == 'ss' && index(credentials,':') < 0) credentials = base64(credentials);
 let ordered = {}; for (let key in sort(keys(parameters))) ordered[key] = parameters[key];
 return {protocol:protocol,endpoint:endpoint(hp[1],hp[2]),credentials:credentials,transport:parameters.type || parameters.net || 'tcp',security:parameters.security || (protocol in ['trojan','hysteria2','tuic','anytls','https'] ? 'tls' : 'none'),parameters:ordered,name:substr(parts[3] ? decode(parts[3]) : uc(protocol),0,100)};
};
export function parse_profile(content) {
 require_value(type(content) == 'string' && length(content) > 0 && length(content) <= 262144, 'INPUT_SIZE');
 let raw = trim(content), model;
 if (match(raw,/^\s*\[Interface\]/i)) {
  require_value(!match(raw,/(^|\n)\s*(PreUp|PostUp|PreDown|PostDown|SaveConfig)\s*=/i),'UNSAFE_WIREGUARD_DIRECTIVE');
  require_value(!!match(raw,/(^|\n)\s*PrivateKey\s*=\s*[A-Za-z0-9+/]{43}=/) && !!match(raw,/\[Peer\]/i), 'BAD_WIREGUARD');
  model=parse_wireguard(raw);
 } else if (match(raw,/(^|\n)\s*(client|remote\s|<ca>)/)) {
  require_value(!match(raw,/(^|\n)\s*(--)?(up|down|route-up|route-pre-down|ipchange|script-security|plugin|config|management|daemon|cd|log|log-append|status|writepid|tls-verify|auth-user-pass-verify|client-connect|client-disconnect|learn-address|iproute)\b/i),'UNSAFE_OPENVPN_DIRECTIVE');
  model=parse_openvpn(raw);
 } else if (substr(raw,0,1) == '{') {
  let fields; try { fields=json(raw); } catch(e) { die('BAD_JSON'); }
  require_value(type(fields)=='object' && type(fields.outbounds)=='array', 'UNKNOWN_JSON_SCHEMA');
  model={protocol:'native-json',name:'Native JSON',transport:'native',security:'native',parameters:{},endpoint:null,credentials:null};
 } else model=uri(raw);
 let identity = json(sprintf('%J',model)); delete identity.name;
 if(model.protocol=='vmess') delete identity.parameters.ps;
 // Native formats retain the complete original payload; no lossy conversion.
 let fingerprint=sha256(model.protocol in ['wireguard','openvpn','native-json'] ? raw : sprintf('%J',identity));
 return {id:fingerprint,model:model,original:raw,created_at:time(),parse_status:'parsed',native_status:'not_checked',handshake_status:'not_tested',enabled:false,sources:[]};
};
function format_result(result){let profiles=[];for(let item in result.models){let identity=json(sprintf('%J',item.model));delete identity.name;let profile={id:sha256(sprintf('%J',identity)),model:item.model,original:item.original,created_at:time(),parse_status:'parsed',native_status:'not_checked',handshake_status:'not_tested',enabled:false,sources:[]};push(profiles,profile);}return {profiles:profiles,errors:result.errors||[],warnings:result.warnings||[]};}
export function extract_profiles(body) {
 require_value(type(body)=='string' && length(body)<=1048576,'SOURCE_SIZE');
 let text=trim(body);
 if (!length(text)) die('EMPTY_SOURCE');
 if(match(text,/(^|\n)proxies:[ \t]*(\n|\[)/))return format_result(clash_profiles(yaml_document(text)));
 // Explicit API envelopes; never recursively treat arbitrary JSON strings as credentials or URLs.
 if(substr(text,0,1)=='{' || (substr(text,0,1)=='['&&!match(text,/^\[Interface\]/i))){
  let payload;try{payload=json(text);}catch(e){die('BAD_JSON_SOURCE');}
  if(type(payload)=='object'&&payload.proxies)return format_result(clash_profiles(payload));
  if(type(payload)=='object'&&type(payload.outbounds)=='array'&&length(payload.outbounds))return format_result(native_json_models(payload));
  let links=type(payload)=='array'?payload:type(payload)=='object'?(payload.links||payload.profiles):null;
  if(links!=null){
   require_value(type(links)=='array'&&length(links)>0&&length(links)<=500,'BAD_JSON_PROFILE_LIST');
   for(let item in links)require_value(type(item)=='string'&&!match(item,/[\r\n]/),'BAD_JSON_PROFILE_ITEM');
   text=join('\n',links);
  }
 }
 if (!match(text,/:\/\/|^\{|^\[Interface\]|(^|\n)client\b/)) text=base64(replace(text,/\s/g,''));
 let inputs=match(text,/^\{|^\[Interface\]|(^|\n)client\b/) ? [text] : filter(split(text,/\r?\n/),line=>length(trim(line)) && !match(line,/^\s*#/));
 require_value(length(inputs)<=500,'TOO_MANY_PROFILES');
 let profiles=[], errors=[];
 for (let i,line in inputs) {
  try { push(profiles,parse_profile(trim(line))); } catch(e) { push(errors,{line:i+1,code:e.message || 'INVALID_INPUT'}); }
 }
 return {profiles:profiles,errors:errors};
};
export function metadata(profile) {
 let m=profile.model,p=m.parameters||{},warnings=[];if(m.transport in ['tcp','raw']&&(!p.headerType||p.headerType=='none')&&(p.host||(p.path&&p.path!='/')))push(warnings,'TCP_WITHOUT_HTTP_HEADER_IGNORES_HOST_PATH');
 return {id:profile.id,compatibility_warnings:warnings,openvpn_credentials_saved:!!profile.openvpn_auth||!!profile.model.credentials?.inline_material?.['auth-user-pass'],provider_tested:profile.model.protocol=='openvpn'?!!profile.last_test?.ok:null,name:profile.model.name,protocol:profile.model.protocol,endpoint:profile.model.endpoint,transport:profile.model.transport,security:profile.model.security,created_at:profile.created_at,parse_status:profile.parse_status,native_status:profile.native_status,tls_mode:profile.tls_mode||'inherit',native_core:profile.native_core,native_core_version:profile.native_core_version,native_error:profile.native_error,handshake_status:profile.handshake_status,enabled:profile.enabled,sources:profile.sources,source_retired:!!profile.source_retired,last_performance:profile.last_performance,last_udp_test:profile.last_udp_test,last_test:profile.last_test};
};
