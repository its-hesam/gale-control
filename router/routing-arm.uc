import {readfile,writefile,chmod} from 'fs';
import {connect} from 'ubus';
import {sha256} from 'digest';
if(sha256(readfile('/etc/gale/routing-active.json')||readfile('/etc/gale/routing-draft.json')||'')!=sha256(readfile('/etc/gale/routing-test/draft.json')||''))die('ROUTING_DRAFT_CHANGED_REPREPARE');
let status=connect().call('gale-connection','status',{});
if(!status?.running||!status.health?.ok||time()-status.health.checked_at>90)die('HEALTHY_LOCAL_PROXY_REQUIRED');
let memory=match(readfile('/proc/meminfo')||'',/MemAvailable:\s*([0-9]+)/);if(!memory||+memory[1]<196608)die('ROUTING_TRIAL_RAM_BUDGET');
let uptime=+split(readfile('/proc/uptime')||'0',' ')[0];if(uptime<=0)die('UPTIME_UNAVAILABLE');
let udp=trim(readfile('/etc/gale/routing-test/trial-mode')||'')=='tcp_udp';
if(udp){let probe=connect().call('gale-connection','status',{}).udp;if(!probe?.ok||!(probe.method in ['SOCKS5_UDP_NTP','SOCKS5_UDP_DNS'])||time()-probe.tested_at>90)die('RECENT_ACTIVE_UDP_TEST_REQUIRED');}
let value={armed_at:time(),deadline_uptime:uptime+90,boot_id:trim(readfile('/proc/sys/kernel/random/boot_id')||''),scope:udp?'all_LAN_IPv4_TCP_UDP_trial':'all_LAN_IPv4_TCP_trial',automatic_rollback:true};
if(ARGV[0]=='session'){value.session=true;value.scope='all_LAN_IPv4_TCP_UDP_session';value.deadline_uptime=null;value.automatic_rollback=false;}
if(!writefile('/etc/gale/routing-test/armed',sprintf('%J',value)))die('WATCHDOG_ARM_FAILED');chmod('/etc/gale/routing-test/armed',0o600);
