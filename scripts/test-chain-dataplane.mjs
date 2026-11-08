import {readFileSync,writeFileSync} from 'node:fs';import {spawnSync} from 'node:child_process';import assert from 'node:assert/strict';function ssh(c,input){let r=spawnSync('ssh',['-o','BatchMode=yes','root@192.168.10.1',c],{input,encoding:'utf8',timeout:20000});assert.equal(r.status,0,r.stdout+r.stderr);return r.stdout;}
ssh('cat >/tmp/gale-chain-dataplane.uc',readFileSync('tests/chain-dataplane.uc'));const out=ssh('sh',`set -eu
umask 077
d=$(mktemp -d /tmp/gale-chain-XXXXXX)
p1=''; p2=''; p3=''
cleanup(){ for p in "$p1" "$p2" "$p3"; do test -z "$p" || kill "$p" 2>/dev/null || true; done; rm -f "$d/client.json" "$d/clash-client.json" "$d/clash-binary" "$d/server.json" "$d/binary" "$d/index.html" "$d/client.log" "$d/server.log"; rmdir "$d"; }
trap cleanup EXIT HUP INT TERM
ucode /tmp/gale-chain-dataplane.uc "$d"
read -r b <"$d/binary"
"$b" check -c "$d/client.json"
"$b" check -c "$d/server.json"
printf 'GALE_CHAIN_OK' >"$d/index.html"
chmod 755 "$d"
chmod 644 "$d/index.html"
/usr/sbin/uhttpd -f -p 127.0.0.1:18103 -h "$d" >/dev/null 2>&1 &
p1=$!
"$b" run -c "$d/server.json" >"$d/server.log" 2>&1 &
p2=$!
"$b" run -c "$d/client.json" >"$d/client.log" 2>&1 &
p3=$!
sleep 1
reply=$(curl -sS --noproxy "" --max-time 8 --socks5-hostname 127.0.0.1:18100 http://127.0.0.1:18103/index.html)
test "$reply" = GALE_CHAIN_OK
kill "$p3"; wait "$p3" || true
read -r cb <"$d/clash-binary"
"$cb" run -c "$d/clash-client.json" >"$d/client.log" 2>&1 &
p3=$!
sleep 1
test "$(curl -sS --noproxy '' --max-time 8 --socks5-hostname 127.0.0.1:18100 http://127.0.0.1:18103/index.html)" = GALE_CHAIN_OK
echo '{"real_two_hop_HTTP_over_SOCKS":true,"imported_native_detour":true,"Clash_dialer_proxy_roundtrip":true,"physical_LAN_changed":false}'
`);writeFileSync('docs/chain-dataplane-result.json',out.trim());console.log(out);
