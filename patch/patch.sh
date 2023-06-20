 moddir=$(dirname $(perl -MNet::BGP::Peer -e 'print $INC{"Net/BGP/Peer.pm"}'))
 pwddir=$(pwd)
 (cd $moddir ; patch < $pwddir/ipv6_bgpnet-0.1.patch)
 