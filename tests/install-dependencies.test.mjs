import {test} from 'node:test';import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {dependencyScript} from '../scripts/install-dependencies.mjs';
const shell=process.platform==='win32'?'C:/Program Files/Git/bin/bash.exe':'/bin/sh';
function exercise(fail=false){
 const setup=`set -eu
fixture_dir=$(mktemp -d)
export fixture_dir
trap 'rm -f "$fixture_dir/apk" "$fixture_dir/uclient-fetch" "$fixture_dir/timeout" "$fixture_dir/log" "$fixture_dir/first"; rmdir "$fixture_dir"' EXIT
cat >"$fixture_dir/uclient-fetch" <<'MOCK'
#!/bin/sh
test "$1" = -4 || exit 91
printf 'fetch %s\\n' "$*" >>"$fixture_dir/log"
MOCK
cat >"$fixture_dir/apk" <<'MOCK'
#!/bin/sh
echo "apk $*" >>"$fixture_dir/log"
case "$1" in
update|add|fix) wget -q -T 20 https://fixture.invalid/package -O - ;;
esac
${fail?'exit 7':''}
MOCK
cat >"$fixture_dir/timeout" <<'MOCK'
#!/bin/sh
echo "version $*" >>"$fixture_dir/log"
if [ "$2" = /usr/bin/sing-box ] && [ ! -f "$fixture_dir/first" ]; then touch "$fixture_dir/first"; exit 1; fi
MOCK
chmod 700 "$fixture_dir/apk" "$fixture_dir/uclient-fetch" "$fixture_dir/timeout"
export PATH="$fixture_dir:$PATH"
set +e
(
${dependencyScript.replace('/tmp/gale-fetch.','$fixture_dir/gale-fetch.')}
)
status=$?
set -e
cat "$fixture_dir/log"
for leftover in "$fixture_dir"/gale-fetch.*; do test ! -e "$leftover" || { echo 'WRAPPER_LEAK'; exit 99; }; done
exit "$status"
`;
 return spawnSync(shell,[],{input:setup,encoding:'utf8',timeout:10000});
}
test('apk downloads use scoped IPv4 wrapper; interrupted core is repaired and wrapper cleaned',()=>{
 const r=exercise();assert.equal(r.status,0,r.stderr+'\n'+r.stdout);assert.match(r.stdout,/fetch -4 -q -T 20 https:\/\/fixture.invalid\/package -O -/);assert.match(r.stdout,/apk fix sing-box/);assert.doesNotMatch(r.stdout,/apk fix xray-core|WRAPPER_LEAK/);
 assert(!/--no-check-certificate|--allow-untrusted|\n(?:uci|nft|sysctl) /.test(dependencyScript));
});
test('failed package refresh stops before add and still cleans temporary wrapper',()=>{
 const r=exercise(true);assert.equal(r.status,7,r.stderr+'\n'+r.stdout);assert.doesNotMatch(r.stdout,/apk add |apk fix |WRAPPER_LEAK/);
});
