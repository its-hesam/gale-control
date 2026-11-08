#!/bin/sh
set -eu
umask 077
server_ns=gale-ovpn-server-test
client_ns=gale-ovpn-client-test
for ns in "$server_ns" "$client_ns"; do if ip netns list | grep -q "^$ns "; then echo TEST_NAMESPACE_BUSY; exit 1; fi; done
dir=$(mktemp -d /tmp/gale-openvpn-test-XXXXXX)
cleanup() {
 for ns in "$client_ns" "$server_ns"; do
  ip netns pids "$ns" 2>/dev/null | while read -r pid; do kill "$pid" 2>/dev/null || true; done
  ip netns del "$ns" 2>/dev/null || true
 done
 rm -f "$dir/ca.key" "$dir/ca.pem" "$dir/ca.srl" "$dir/server.key" "$dir/server.pem" "$dir/server.csr" "$dir/server.ext" "$dir/client.key" "$dir/client.pem" "$dir/client.csr" "$dir/client.ext" "$dir/cert.json" "$dir/cert.pem" "$dir/key.pem" "$dir/server.conf" "$dir/client.conf" "$dir/server.log" "$dir/client.log" "$dir/index.html" "$dir/response"
 rm -f "$dir/www/index.html"
 rmdir "$dir/www" 2>/dev/null || true
 rmdir "$dir" 2>/dev/null || true
}
trap cleanup EXIT HUP INT TERM
ip netns add "$server_ns"
ip netns add "$client_ns"
ip link add gale-ovs-test type veth peer name gale-ovc-test
ip link set gale-ovs-test netns "$server_ns"
ip link set gale-ovc-test netns "$client_ns"
ip -n "$server_ns" link set lo up
ip -n "$client_ns" link set lo up
ip -n "$server_ns" address add 10.253.254.1/30 dev gale-ovs-test
ip -n "$client_ns" address add 10.253.254.2/30 dev gale-ovc-test
ip -n "$server_ns" link set gale-ovs-test up
ip -n "$client_ns" link set gale-ovc-test up
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -noenc -keyout "$dir/ca.key" -out "$dir/ca.pem" -subj /CN=GaleFixtureCA -days 1 -addext basicConstraints=critical,CA:TRUE -addext keyUsage=critical,keyCertSign,cRLSign >/dev/null 2>&1
for role in server client; do
 openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:P-256 -noenc -keyout "$dir/$role.key" -out "$dir/$role.csr" -subj "/CN=gale-$role" >/dev/null 2>&1
 usage=serverAuth; [ "$role" = server ] || usage=clientAuth
 printf 'basicConstraints=CA:FALSE\nkeyUsage=digitalSignature,keyAgreement\nextendedKeyUsage=%s\n' "$usage" >"$dir/$role.ext"
 openssl x509 -req -in "$dir/$role.csr" -CA "$dir/ca.pem" -CAkey "$dir/ca.key" -CAcreateserial -out "$dir/$role.pem" -days 1 -extfile "$dir/$role.ext" >/dev/null 2>&1
done
cat >"$dir/server.conf" <<EOF
local 10.253.254.1
port 18884
proto udp
dev galetestserver
dev-type tun
topology subnet
server 10.253.253.0 255.255.255.0
ca $dir/ca.pem
cert $dir/server.pem
key $dir/server.key
dh none
verify-client-cert require
remote-cert-tls client
disable-dco
verb 3
EOF
# No client certificate is requested in this isolated fixture.

cat >"$dir/client.conf" <<EOF
client
proto udp
remote 10.253.254.1 18884
dev galetestclient
dev-type tun
nobind
ca $dir/ca.pem
cert $dir/client.pem
key $dir/client.key
remote-cert-tls server
disable-dco
route-nopull
verb 3
EOF
mkdir "$dir/www"
chmod 755 "$dir" "$dir/www"
printf 'GALE_OPENVPN_ISOLATED_OK\n' >"$dir/www/index.html"
chmod 644 "$dir/www/index.html"
ip netns exec "$server_ns" /usr/bin/timeout 35 /usr/sbin/openvpn --config "$dir/server.conf" >"$dir/server.log" 2>&1 &
sleep 1
ip netns exec "$client_ns" /usr/bin/timeout 35 /usr/sbin/openvpn --config "$dir/client.conf" >"$dir/client.log" 2>&1 &
ready=no
for attempt in 1 2 3 4 5 6 7 8 9 10 11 12; do
 if grep -q 'Initialization Sequence Completed' "$dir/client.log"; then ready=yes; break; fi
 sleep 1
done
if [ "$ready" != yes ]; then
 echo ISOLATED_OPENVPN_HANDSHAKE_NOT_READY
 # Synthetic fixture logs contain no user VPN material.
 tail -n 10 "$dir/server.log"
 tail -n 10 "$dir/client.log"
 exit 1
fi
ip netns exec "$server_ns" /usr/bin/timeout 12 /usr/sbin/uhttpd -f -p 10.253.253.1:18080 -h "$dir/www" >/dev/null 2>&1 &
sleep 1
ip netns exec "$client_ns" /usr/bin/curl --disable --silent --show-error --proxy '' --noproxy '*' --max-time 8 --write-out "HTTP_STATUS=%{http_code}\n" --output "$dir/response" http://10.253.253.1:18080/index.html
cmp -s "$dir/response" "$dir/www/index.html"
printf '{"openvpn_tls_handshake":true,"encrypted_tun_dataplane":true,"isolated_namespaces":true,"user_provider_config_tested":false}\n'
