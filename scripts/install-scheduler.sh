#!/bin/sh
set -eu
test -x /usr/share/gale/source-scheduler
directory=$(mktemp -d /tmp/gale-cron-XXXXXX)
trap 'rm -f "$directory/original" "$directory/new"; rmdir "$directory"' EXIT
crontab -l >"$directory/original" 2>/dev/null || true
if grep -q '# gale-source-scheduler$' "$directory/original"; then echo 'Scheduler already registered'; exit 0; fi
umask 077
test -f /root/gale-cron-before.txt || cp "$directory/original" /root/gale-cron-before.txt
cat "$directory/original" >"$directory/new"
printf '\n*/5 * * * * /usr/share/gale/source-scheduler >/dev/null 2>&1 # gale-source-scheduler\n' >>"$directory/new"
crontab "$directory/new"
echo 'Opt-in source scheduler installed; no source schedule enabled by default.'
