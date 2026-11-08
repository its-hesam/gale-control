#!/bin/sh
echo REPOS
cat /etc/apk/repositories.d/distfeeds.list /etc/apk/repositories.d/customfeeds.list
echo RPCD
cat /etc/config/rpcd
echo PLUGINS
ls -l /usr/libexec/rpcd
echo BOOTLOG
dmesg | grep -i -E 'coreboot|depthcharge|mmc|ipq4019' | head -n 12
echo PASSWALL
nft list table inet passwall2 | head -n 30
echo SHADOW_STATE
awk -F: '$1 == "root" {print ($2 == "" ? "root password empty" : "root password hash or lock present")}' /etc/shadow
