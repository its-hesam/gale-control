#!/bin/sh
set -eu
state=/root/gale-migration-20261107
test -f "$state/enabled-services"
while read -r name; do
 case "$name" in openvpn|passwall2|passwall2_server|v2raya|xray|naiveproxy) "/etc/init.d/$name" enable ;; *) exit 1 ;; esac
done < "$state/enabled-services"
echo 'Original boot enablement restored. No tunnel was started; startup requires an explicit action.'
