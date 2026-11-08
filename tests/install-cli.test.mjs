import {test} from 'node:test';import assert from 'node:assert/strict';import {spawnSync} from 'node:child_process';
const run=args=>spawnSync(process.execPath,['scripts/install.mjs',...args],{encoding:'utf8',timeout:3000});
test('installer help works without SSH or a router',()=>{const r=run(['--help']);assert.equal(r.status,0);assert.match(r.stdout,/--check is read-only/)});
test('installer rejects shell metacharacters in a destination before SSH',()=>{const r=run(['--host','root@router;echo','--check']);assert.notEqual(r.status,0);assert.match(r.stderr,/Use --host root@hostname/)});
test('installer requires a root destination and a host value',()=>{for(const args of [['--host','admin@router'],['--host']]){const r=run(args);assert.notEqual(r.status,0);assert.match(r.stderr,/Use --host root@hostname/)}});
test('installer rejects unknown options instead of silently performing installation',()=>{const r=run(['--unknown']);assert.notEqual(r.status,0);assert.match(r.stderr,/Unknown option/)});

test('installer documents masked password login and rejects conflicting auth modes before connecting',()=>{assert.match(run(['--help']).stdout,/--password/);const r=run(['--password','--batch']);assert.notEqual(r.status,0);assert.match(r.stderr,/Choose either --password or --batch/);assert.doesNotMatch(r.stderr,/at ssh|file:/);});
