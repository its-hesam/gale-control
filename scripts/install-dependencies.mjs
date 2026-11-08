import {runStage} from './command-progress.mjs';
export const dependencyPackages='ucode ucode-mod-fs ucode-mod-digest ucode-mod-socket ucode-mod-ubus ucode-mod-uci rpcd rpcd-mod-ucode uhttpd uhttpd-mod-ubus curl ca-bundle lua lyaml ip-full nftables-json kmod-nft-tproxy kmod-nft-socket unzip xray-core sing-box';
export const dependencyScript=`set -eu
command -v apk >/dev/null || { echo 'This installer expects apk on OpenWrt25.12.' >&2; exit 1; }
GALE_FETCH_BIN=$(command -v uclient-fetch)
case "$GALE_FETCH_BIN" in /*) ;; *) echo 'An absolute uclient-fetch path is required.' >&2; exit 1 ;; esac
export GALE_FETCH_BIN
umask 077
gale_fetch_dir=$(mktemp -d /tmp/gale-fetch.XXXXXX)
cleanup() { rm -f "$gale_fetch_dir/wget"; rmdir "$gale_fetch_dir"; }
trap cleanup EXIT
trap 'exit 130' INT TERM
printf '%s\\n' '#!/bin/sh' 'exec "$GALE_FETCH_BIN" -4 "$@"' >"$gale_fetch_dir/wget"
chmod 700 "$gale_fetch_dir/wget"
export PATH="$gale_fetch_dir:$PATH"
echo '[Dependencies] Using IPv4 for apk downloads in this process only; HTTPS and package signatures remain enabled.'
apk update
apk add ${dependencyPackages}
# Repair a core left incomplete by an earlier interrupted package extraction.
if ! timeout 15 /usr/bin/sing-box version; then
 echo '[Dependencies] Repairing incomplete sing-box package.'
 apk fix sing-box
 timeout 15 /usr/bin/sing-box version
fi
if ! timeout 15 /usr/bin/xray version; then
 echo '[Dependencies] Repairing incomplete xray-core package.'
 apk fix xray-core
 timeout 15 /usr/bin/xray version
fi
echo '[Dependencies] Both core executables passed version checks.'
`;
export async function installDependencies(transport){
 await runStage(transport,{label:'Installing dependencies over IPv4',script:dependencyScript,timeout:900000,timeoutAdvice:'The remote apk operation may still be running; inspect it before retrying. VPN routing was not activated by this stage.'});
}
