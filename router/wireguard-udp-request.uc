import {test_udp_proxy} from '/usr/share/gale/lib/udp.uc';let result=test_udp_proxy('dns',17891,'8.8.8.8');print(result);exit(result.ok?0:1);
