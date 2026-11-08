import {readfile,stat,unlink} from 'fs';
// Caller holds restore-stage.lock. Token never becomes a filesystem path.
export function uploaded_profiles(token){
 let meta;try{meta=json(readfile('/tmp/gale-backup-upload.meta')||'null');}catch(e){}
 if(!meta||meta.target!='profiles'||type(token)!='string'||token!=meta.token||time()-meta.at>900)die('PROFILE_UPLOAD_EXPIRED');
 if(meta.bytes<1||meta.bytes>1048576||stat('/tmp/gale-backup-upload.part')?.size!=meta.bytes)die('PROFILE_UPLOAD_INCOMPLETE');
 let content=readfile('/tmp/gale-backup-upload.part');unlink('/tmp/gale-backup-upload.part');unlink('/tmp/gale-backup-upload.meta');return content;
};
