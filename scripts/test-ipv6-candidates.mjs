import {readFileSync,writeFileSync} from 'node:fs';import {spawnSync} from 'node:child_process';import assert from 'node:assert/strict';function ssh(c,input,timeout=20000){let r=spawnSync('ssh',['-o','BatchMode=yes','root@192.168.10.1',c],{input,encoding:'utf8',timeout});assert.equal(r.status,0,'IPV6_CANDIDATE_TEST_FAILED');return r.stdout;}
ssh('ucode -',readFileSync('tests/ipv6-candidates.uc'));let index=JSON.parse(ssh('cat /tmp/gale-v6-candidates/index.json')),results=[];for(let p of index){let status=ssh('sh',`set -eu
d=/tmp/gale-v6-candidates
read -r b <"$d/${p.index}.bin"
"$b" run -c "$d/${p.index}.json" >"$d/${p.index}.log" 2>&1 &
pid=$!
trap 'kill "$pid" 2>/dev/null || true' EXIT HUP INT TERM
sleep 2
curl -sS --max-time 8 --socks5 127.0.0.1:18501 --resolve 'www.gstatic.com:443:[2a00:1450:4018:811::2003]' -o /dev/null -w '%{http_code}' https://www.gstatic.com/generate_204 2>/dev/null || true
`,15000);results.push({...p,IPv6_literal_HTTPS:status.trim()==='204'});console.log({candidate:p.index,IPv6_literal_HTTPS:status.trim()==='204'});}writeFileSync('.private/ipv6-candidates.json',JSON.stringify(results));writeFileSync('docs/ipv6-candidates-result.json',JSON.stringify(results.map(({id,...r})=>r),null,2));
