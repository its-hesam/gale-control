#!/bin/sh
set -eu
state=/root/gale-migration-20261107
test ! -e "$state"
# Do not disrupt any currently working legacy tunnel.
for binary in openvpn xray sing-box v2raya naive hysteria; do
 if pidof "$binary" >/dev/null; then echo "Refusing migration: $binary is running"; exit 1; fi
done
umask 077
mkdir "$state"
sha256sum /etc/config/network /etc/config/firewall /etc/config/wireless /etc/config/dhcp /etc/config/dropbear /etc/config/uhttpd > "$state/config.sha256"
ip route > "$state/routes.before"
ip rule > "$state/rules.before"
nft list ruleset > "$state/nft.before"
: > "$state/enabled-services"
for name in openvpn passwall2 passwall2_server v2raya xray naiveproxy; do
 if [ -x "/etc/init.d/$name" ] && "/etc/init.d/$name" enabled; then echo "$name" >> "$state/enabled-services"; fi
done
restore_boot() {
 while read -r name; do "/etc/init.d/$name" enable; done < "$state/enabled-services"
}
trap restore_boot EXIT
# Stop only the failed procd respawn instance. No legacy firewall cleanup scripts run.
/etc/init.d/openvpn stop
while read -r name; do "/etc/init.d/$name" disable; done < "$state/enabled-services"
sha256sum -c "$state/config.sha256"
ip route > "$state/routes.after"
ip rule > "$state/rules.after"
nft list ruleset > "$state/nft.after"
cmp "$state/routes.before" "$state/routes.after"
cmp "$state/rules.before" "$state/rules.after"
# nft counters change under traffic; compare rules without counters.
sed -E 's/counter packets [0-9]+ bytes [0-9]+/counter/g' "$state/nft.before" > "$state/nft.before.normalized"
sed -E 's/counter packets [0-9]+ bytes [0-9]+/counter/g' "$state/nft.after" > "$state/nft.after.normalized"
cmp "$state/nft.before.normalized" "$state/nft.after.normalized"
touch "$state/complete"
trap - EXIT
echo 'Legacy boot managers disabled; failed OpenVPN respawn stopped. Binaries and profiles preserved.'
cat "$state/enabled-services"
