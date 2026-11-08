import {readFileSync,writeFileSync} from 'node:fs';import {spawnSync} from 'node:child_process';import assert from 'node:assert/strict';function ssh(c,input){let r=spawnSync('ssh',['-o','BatchMode=yes','root@192.168.10.1',c],{input,encoding:'utf8',timeout:35000});assert.equal(r.status,0,r.stderr||'WG_MULTI_DATAPLANE_FAILED');return r.stdout;}
ssh('cat >/tmp/gale-wg-multi.uc',readFileSync('tests/wireguard-multi-dataplane.uc'));let result=ssh('sh',`set -eu
umask 077
d=$(mktemp -d /tmp/gale-wg-multi-XXXXXX)
pc=''; p1=''; p2=''
cleanup(){ for p in "$pc" "$p1" "$p2"; do test -z "$p" || kill "$p" 2>/dev/null || true; done; ip netns del gale-wg-1 2>/dev/null || true; ip netns del gale-wg-2 2>/dev/null || true; ip link del gale-wg-1 2>/dev/null || true; ip link del gale-wg-2 2>/dev/null || true; rm -f "$d"/client.key "$d"/client.pub "$d"/peer1.key "$d"/peer1.pub "$d"/peer2.key "$d"/peer2.pub "$d"/client.json "$d"/binary "$d"/index.html "$d"/engine.log; rmdir "$d"; }
test ! -e /var/run/netns/gale-wg-1; test ! -e /var/run/netns/gale-wg-2
trap cleanup EXIT HUP INT TERM
wg genkey >"$d/client.key"; wg pubkey <"$d/client.key" >"$d/client.pub"
for n in 1 2; do
 wg genkey >"$d/peer$n.key"; wg pubkey <"$d/peer$n.key" >"$d/peer$n.pub"
 ip netns add gale-wg-$n
 ip link add gale-wg-$n type wireguard
 wg set gale-wg-$n private-key "$d/peer$n.key" listen-port $((18400+n)) peer "$(cat "$d/client.pub")" allowed-ips 10.253.0.2/32
 ip link set gale-wg-$n netns gale-wg-$n
 ip -n gale-wg-$n addr add 10.253.$n.1/32 dev gale-wg-$n
 ip -n gale-wg-$n link set lo up
 ip -n gale-wg-$n link set gale-wg-$n up
 ip -n gale-wg-$n route add 10.253.0.2/32 dev gale-wg-$n
done
printf 'WG_MULTI_OK' >"$d/index.html"; chmod 755 "$d"; chmod 644 "$d/index.html"
ip netns exec gale-wg-1 /usr/sbin/uhttpd -f -p 10.253.1.1:18403 -h "$d" >/dev/null 2>&1 &
p1=$!
ip netns exec gale-wg-2 /usr/sbin/uhttpd -f -p 10.253.2.1:18403 -h "$d" >/dev/null 2>&1 &
p2=$!
ucode /tmp/gale-wg-multi.uc "$d"
read -r b <"$d/binary"
"$b" check -c "$d/client.json" >/dev/null 2>&1
"$b" run -c "$d/client.json" >"$d/engine.log" 2>&1 &
pc=$!
sleep 1
for n in 1 2; do
 test "$(curl -sS --noproxy '' --max-time 10 --socks5-hostname 127.0.0.1:18400 http://10.253.$n.1:18403/index.html)" = WG_MULTI_OK
 test "$(ip netns exec gale-wg-$n wg show gale-wg-$n latest-handshakes | awk '{print $2}')" -gt 0
done
echo '{"encrypted_peers_tested":2,"both_peer_HTTP_payloads":true,"both_handshakes":true,"physical_LAN_changed":false}'
`);writeFileSync('docs/wireguard-multi-dataplane-result.json',result.trim());console.log(result);
