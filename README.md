# BGP Replay Tool
BGP replay tool, based on the work by CAIA, Swinburne University of Technology
(http://caia.swin.edu.au/tools/bgp/brt/downloads.html).

I added a small feature so you can also inject BGP updates to a running BRT via a named pipe.
```
BRT-0.2.1: BGP Replay Tool script.

usage:
 BRT-0.2.1.pl
  -brtas <AS number>	# your AS number
  -brtip <IP address>	# your IP address
  -brtipv6 <IPv6 address>	# your/next-hop IPv6 address
  -peeras <AS number>	# peer AS number
  -peerip <IP address>	# peer IP address
  -peeripv6 <IPv6 address>	# peer IPv6 address
  [-ipv6] 		# connect to peer using IPv6
  [-m <Filename>]	# connect to multiple peers specified in <Filename>
  -f <Filename>		# BGP update file in human readable with Unix format (bgpdump -m option)
  [-u <Named pipe>]	# named pipe for sending BGP updates; use same format as the BGP update file
  [-c <Filename>]	# check the existence of AS numbers in <Filename> 
			# in AS-PATH of the injected updates
  [-help]		# Display BRT tool help
  [-l]			# Allow BRT to listen on port 179
  [-v]			# log to stdout
```
Example:
1. Starting BRT
   
    ```
   perl brt-0.2.1.pl -brtas 65001 -brtip 172.16.2.2 -peeras 65002 -peerip 172.16.2.1 -f bgpdump -u update.pipe
    ```
   
3. Sending BGP updates (up to 640KB)
   
   ```
   cat bgpdump-update > update.pipe
   ```

Refer to README-brt.txt for the details.
