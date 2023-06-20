-------------------------------------------------------------------------------
School of Software and Electrical Engineering,
Swinburne University of Technology,
Melbourne, Australia

June, 2017
BRT v0.2: BGP replay tool v0.2

Author: Rasool Al-Saadi <ralsaadi@swin.edu.au>
-------------------------------------------------------------------------------


1. OVERVIEW
------------
BGP replay tool v0.2 (BRT v0.2) is tool for UNIX operating systems
providing the ability to replay previously BGP updates downloaded 
from the public route repositories or local log files to test a 
variety of operations.
BRT enables users to send out BGP updates from a predefined BGP
update file. BGP session and message handling are done by Net::BGP v0.16,
a Perl module that implements BGP-4 inter-domain routing protocol.
This tool helps researchers and operators to understand BGP behaviour
during different circumstances.


2. USAGE
---------
Execute BRT tool as follows:

    perl brt-0.2.pl [arguments]

The arguments are:
  -brtas <AS number>    # your AS number
  -brtip <IP address>   # your IP address
  -brtipv6 <IPv6 address>   # your/next-hop IPv6 address
  -peeras <AS number>   # peer AS number
  -peerip <IP address>  # peer IP address
  -peeripv6 <IPv6 address>  # peer IPv6 address
  [-ipv6]           # connect to peer using IPv6
  [-m <Filename>]   # connect to multiple peers specified in <Filename>
  -f <Filename>     # BGP update file in human readable with Unix format (bgpdump -m option)
  [-c <Filename>]   # check the existence of AS numbers in <Filename> 
                    # in AS-PATH of the injected updates
  [-help]           # Display BRT tool help
  [-l]              # Allow BRT to listen on port 179
  [-v]              # log to stdout

Example 1:
    perl brt-0.2.pl -brtas 65001 -brtip 172.16.2.2 -peeras 65002 -peerip 172.16.2.1 -f in

Example 2:
    perl brt-0.2.pl -brtas 65002 -brtip 172.16.1.100 -brtipv6 fc00:3::1 -peeras 65001 -peerip 172.16.1.200 -v -f in

3. INSTALL PERL MODULES
--------------------------
BRT v0.2 needs Net::BGP and IO::Socket::INET6 to be install Perl modules to
work properly. To install these module use:

    #perl -MCPAN -e shell
    cpan[1]> install Net::BGP
    cpan[1]> install IO::Socket::INET6


4. APPLY IPV6 BGP PATCH 
------------------------
Net::BGP does not support IPv6 BGP updates. We provide a patch add IPv6 support
for Perl Net::BGP. To apply IPv6 Net::BGP patch, as a super user run:
 
    # tar xzfv brt-0.2.tgz
    # cd brt-0.2/patch/
    # ./patch.sh


5. Notes when experience a problem
-----------------------------------
In case you experience a problem when applying the patch, such as when apply
the patch twice, you need to delete, reinstall and patch the Net::BGP module.
The default folder for the module is located in:
    /usr/local/share/perl/<your_perl_version>/Net/


6. ADDITIONAL INFORMATION
-------------------------
BRT v0.2 tool and other scripts are available at:
    http://caia.swin.edu.au/tools/bgp/brt/brt-0.2.tgz

A technical report about using this tool and other scripts are available at:
    http:///i4t.swin.edu.au/reports/I4TRL-TR-170606A.pdf


7. LICENCE
-----------
This tool is released under a new BSD License. For more details
please refer to the included source files.


8. ACKNOWLEDGEMENTS
-------------------- 
The development of BRT v0.2 has been made possible in part by
"APNIC Internet Operations Research Grant" under the ISIF
Asia 2016 grant scheme.