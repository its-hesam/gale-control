import {readfile} from 'fs';
import {core_config} from '/usr/share/gale/lib/adapter.uc';
import {sha256} from 'digest';
function canonical(value){if(type(value)=='object'){let out={};for(let key in sort(keys(value)))out[key]=canonical(value[key]);return out;}if(type(value)=='array')return map(value,canonical);return value;}
export function config_identity(profile,policy){try{let selected=core_config(profile,policy);return sha256(sprintf('%J',canonical({core:selected.core,config:selected.config})));}catch(e){return null;}};
export function duplicate_index(store){let index={};for(let p in values(store.profiles)){let key=config_identity(p,store.security);if(key&&!exists(index,key))index[key]=p.id;}let active;try{active=json(readfile('/etc/gale/runtime/active')||'null');}catch(e){}let p=store.profiles[active?.profile_id];if(p){let key=config_identity(p,store.security);if(key)index[key]=p.id;}return index;};
export function existing_profile(profile,store,index){if(exists(store.profiles,profile.id))return profile.id;let key=config_identity(profile,store.security);if(key&&index[key])return index[key];if(key)index[key]=profile.id;return null;};
