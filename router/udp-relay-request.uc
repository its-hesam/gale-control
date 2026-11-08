// Private bounded test helper: destination is always the local SOCKS UDP relay.
import {create,AF_INET,SOCK_DGRAM} from 'socket';
import {readfile} from 'fs';
if(!match(ARGV[0]||'',/^[0-9]{1,5}$/)||+ARGV[0]<1024||+ARGV[0]>65535)die('BAD_LOCAL_RELAY_PORT');
let input=trim(readfile('/dev/stdin')||'');if(length(input)>1024)die('UDP_TEST_INPUT_LIMIT');let packet=b64dec(input);if(!packet||length(packet)>512)die('BAD_UDP_TEST_INPUT');
let sock=create(AF_INET,SOCK_DGRAM,0);if(!sock||!sock.connect('127.0.0.1',+ARGV[0]))die('LOCAL_UDP_SOCKET_FAILED');
if(sock.send(packet)!=length(packet))die('UDP_TEST_SEND_FAILED');let response=sock.recv(2048);sock.close();if(!response)die('UDP_TEST_NO_RESPONSE');print({response:b64enc(response)});
