import {spawnSync} from 'node:child_process';import {readFileSync,writeFileSync} from 'node:fs';function ssh(c,input){let r=spawnSync('ssh',['-o','BatchMode=yes','root@192.168.10.1',c],{input,encoding:'utf8',timeout:20000});if(r.status)throw Error((r.stdout||'')+(r.stderr||'DNS_FIXTURE_FAILED'));return r.stdout;}for(const [a,b] of [['tests/wireguard-dns-fixture.uc','/tmp/gale-dns-fixture.uc'],['tests/dns-fallback-query.uc','/tmp/gale-dns-query.uc']])ssh('cat >'+b,readFileSync(a));
let result=ssh('sh',`set -eu
umask 077
d=$(mktemp -d /tmp/gale-dns-XXXXXX)
p1=''; p2=''; p3=''
cleanup(){ for p in "$p1" "$p2" "$p3"; do if [ -n "$p" ]; then kill "$p" 2>/dev/null || true; fi; done; rm -f "$d/engine.log" "$d/config.json" "$d/binary" "$d/dnsmasq.pid"; rmdir "$d"; }
trap cleanup EXIT HUP INT TERM
ucode /tmp/gale-dns-fixture.uc "$d"
read -r binary <"$d/binary"
"$binary" check -c "$d/config.json" >/dev/null 2>&1
ucode -e 'import {create,AF_INET,SOCK_DGRAM} from "socket";let s=create(AF_INET,SOCK_DGRAM,0);if(!s.bind("127.0.0.1:15401"))exit(1);system(["/bin/sleep","15"],16000);' >/dev/null 2>&1 &
p1=$!
/usr/sbin/dnsmasq --no-daemon --user=root --port=15402 --listen-address=127.0.0.1 --bind-interfaces --no-resolv --no-hosts --conf-file=/dev/null --address=/gale.test/203.0.113.7 --pid-file="$d/dnsmasq.pid" >/dev/null 2>&1 &
p2=$!
"$binary" run -c "$d/config.json" >"$d/engine.log" 2>&1 &
p3=$!
sleep 1
kill -0 "$p1"; kill -0 "$p2"; kill -0 "$p3"
timeout 8 ucode /tmp/gale-dns-query.uc
`);console.log(result);writeFileSync('docs/dns-fallback-result.json',result.trim());
