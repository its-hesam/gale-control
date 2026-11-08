import { open, readfile, writefile, rename, chmod, stat, mkdir } from 'fs';
let override=getenv('GALE_TEST_STORE');
let directory=override && match(override,/^\/tmp\/gale-test-[a-zA-Z0-9-]+$/) ? override : '/etc/gale';
export function lock_store() {
 if (!stat(directory)) { if (!mkdir(directory)) die('STORE_CREATE_FAILED'); }
 chmod(directory,0o700);
 let lock=open(directory+'/store.lock','a',0o600);
 if (!lock || !lock.lock('xn')) die('STORE_BUSY');
 return lock;
};
export function load_store() {
 let raw=readfile(directory+'/state.json');
 if (raw==null) return {schema_version:1,profiles:{},sources:{}};
 let store; try {store=json(raw);} catch(e) {die('STORE_CORRUPT');}
 if (store.schema_version!=1 || type(store.profiles)!='object' || type(store.sources)!='object') die('STORE_CORRUPT');
 return store;
};
export function save_store(store) {
 let serialized=sprintf('%J',store);
 if (length(serialized)>8388608 || length(keys(store.profiles))>2000) die('STORE_LIMIT');
 let fp=open(directory+'/state.new','w',0o600);
 if (!fp) die('STORE_WRITE_FAILED');
 chmod(directory+'/state.new',0o600);
 let count=fp.write(serialized); let flushed=fp.flush(); fp.close();
 if (count!=length(serialized) || !flushed) die('STORE_WRITE_FAILED');
 // rename within one filesystem: readers see either the last complete state or new state.
 if (!rename(directory+'/state.new',directory+'/state.json')) die('STORE_COMMIT_FAILED');
};
