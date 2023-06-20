#!/usr/bin/perl
####################################################################################
# Copyright (c) 2017, School of Software and Electrical Engineering
# Swinburne University of Technology, Melbourne, Australia
####################################################################################
# BRT-0.2.1: A script to replay past BGP updates from a selected file
#
# This software was modified by Achmad Husni Thamrin <ahthamrin@gmail.com>
# This software was developed by Rasool Al-Saadi <ralsaadi@swin.edu.au>
# The original version was developed by Bahaa Al-Musawi <balmusawi@swin.edu.au>
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. The names of the authors, the "Centre for Advanced Internet Architecture"
#    and "Swinburne University of Technology" may not be used to endorse
#    or promote products derived from this software without specific
#    prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHORS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHORS OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
# Please e-mail any bugs, suggestions and feature requests to <ralsaadi@swin.edu.au>
###############################################################################

# import the necessary modules
use Net::BGP::Process;
use Net::BGP::Peer;
use Getopt::Long;
use Getopt::Long qw(GetOptionsFromString);

use Data::Dumper qw(Dumper);
use Time::HiRes qw(usleep);
use Time::HiRes qw(gettimeofday);

use Fcntl;
use Errno;

# http://www.iana.org/assignments/bgp-parameters/bgp-parameters.xhtml
my %BGP_ERROR_CODES_SUBCODES = (
    1 => {	__NAME__ => "Message Header Error", 
            1 => "Connection Not Synchronized", 
            2 => "Bad Message Length", 
            3 => "Bad Message Type",
    },
    2 => {	__NAME__ => "OPEN Message Error",
            1 => "Unsupported Version Number",
            2 => "Bad Peer AS",
            3 => "Bad BGP Identifier",
            4 => "Unsupported Optional Parameter",
            5 => "[Deprecated], see RFC4271",
            6 => "Unacceptable Hold Time",
    },
    3 => {	__NAME__ => "UPDATE Message Error",
            1 => "Malformed Attribute List",
            2 => "Unrecognized Well-known Attribute",
            3 => "Missing Well-known Attribute",
            4 => "Attribute Flags Error",
            5 => "Attribute Length Error",
            6 => "Invalid ORIGIN Attribute",
            7 => "[Deprecated], see RFC4271",
            8 => "Invalid NEXT_HOP Attribute",
            9 => "Optional Attribute Error",
            10 => "Invalid Network Field",
            11 => "Malformed AS_PATH",
    },
    4 => {	__NAME__ => "Hold Timer Expired",
    },
    5 => {	__NAME__ => "Finite State Machine Error",
    },
    6 => {	__NAME__ => "Cease NOTIFICATION message",
            1 => "Maximum Number of Prefixes Reached",
            2 => "Administrative Shutdown",
            3 => "Peer De-configured",
            4 => "Administrative Reset",
            5 => "Connection Rejected",
            6 => "Other Configuration Change",
            7 => "Connection Collision Resolution",
            9 => "Out of Resources",
    },
);

my $help = <<EOF;
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
  [-u <Named pipe>]	# named pipe to read a new BGP update file
  [-c <Filename>]	# check the existence of AS numbers in <Filename> 
			# in AS-PATH of the injected updates
  [-help]		# Display BRT tool help
  [-l]			# Allow BRT to listen on port 179
  [-t]			# Ignore replay time
  [-v]			# log to stdout

EOF

my ($brtas, $brtip, $brtipv6, $peeras, $peerip, $peeripv6, $input_file, $named_pipe);
my $holdtime = 180;
my $keepalive = 60;
my $opthelp = 0;
my $optipv6 = 0;
my $optv = 0;
my $optlisten = 0;
my $opttime = 0;
my $multipeer_file = '';
my $asnc_file = '';
my @peers;
my $noofpeers = 1;
my $notready = 1;;
my $connerror = 1;
my $nol = 0;
my $fh;
my @pipe_buffer;
my $ph;

sub sending
{
    my ($is_start) = shift(@_);
    
    # Create BGP objects
    my $update = Net::BGP::Update->new();
    my $nlri = Net::BGP::NLRI->new();
    my $aspath_obj = Net::BGP::ASPath->new([]);

    my $ts_old = 0;
    my $time_old = gettimeofday();
    my $ts_ref = 0;
    my $aprefixes ="";
    my @line_next, @line = ();
    my @prefixes = ();
    my $lastline = 0;
    my $count = 0;
    
    my $process_routes = sub {
        my $row = shift(@_);

        # Split bgpdump fields 
        my @line_next = split '\|', $row;
        
        # Ignore any line not start with "BGP4MP" or "TABLE_DUMP2"
        if (!($line_next[0] eq "BGP4MP") &&
            !($line_next[0] eq "TABLE_DUMP2") && !$lastline) {
            @line = @line_next if ($line[0] eq "");
            next;
        }
        
        if ($line[0] eq "" && !$lastline) {
            @line = @line_next;
            next;
        }
        
        # For sending last update
        if ($lastline) {
            $lastline = 0;
        } else {
            $lastline = eof($fh);
        }
        
        # count number of lines
        $nol = $nol + 1;
        
        # To send multiple updates in one message, we compare the
        # attributes of a new update with the old one and aggregate
        # the similar updates.
        # Note: attribute number 5 is the prefix, we igonre it in the
        # comparison.
        my $same = 1;
        for (my $i = 0; $i < 14; $i += 1) {
            if (!($line_next[$i] eq $line[$i] || $i == 5)) {
                $same = 0;
                last;
            }
        }
        
        # Add the prefix to prefixes list
        push @prefixes, $line[5];
        
        # we aggregate maximume of 150 prefixes to avoid large BGP messages
        if ($same && scalar @prefixes < 150) {
            @line = @line_next;
            next;
        } 

        my $ts =  $line[1];
        if ($opttime) {
            # Sleep for a period to sync the sending time between the orignal
            # and the actual update timestamps
            $ts_ref = $ts if (!$ts_ref);
            if (($ts_old != 0) && ($ts != $ts_old)) {
                my $ts_diff = $ts - $ts_old;
                my $time = gettimeofday();
                my $time_diff = $time - $time_old;
                if ( $ts_diff > $time_diff ) {
                    if ($optv) {
                        my  $tdiff = (int(($ts_diff - $time_diff) * 100)) / 100.0;
                        print "number of updates sent:$count";
                        # print " -- sleep for $tdiff seconds\n";
                    }
                    usleep (($ts_diff - $time_diff) * 1000000);
                } else {
                    print "Warning: Sending the messages took longer than the source messages\n";
                    print "orignal time:$ts_diff, actual time:$time_diff\n" ;
                    print "Number of updates sent during that time:$count\n";
                }
                $time_old = gettimeofday();
                $count = 0;
            }
            $ts_old = $ts;
        }

        my $cmd = $line[2];
        my $next_hop;
        # We don't care about AS_IP, AS and real next_hop
        #my $thisASIP = $line[3];
        #my $thisAS = $line[4];
        #my $next_hop = $line[8];
        
        # Are the prefixes IPv6?
        my $is_ipv6_prefix = 0;
        $is_ipv6_prefix = 1 if ($prefixes[0] =~ /\:/);
        
        if ($is_ipv6_prefix) {
            $next_hop = $brtipv6;
        } else {
            $next_hop = $brtip;
        }
        
        # The message is announcement 
        if ($cmd eq "A" || $cmd eq "B" ) {
            my $ASpath = $line[6];
            my $origin = $line[7];
            my $local_pref = $line[9];
            my $med = $line[10];
            my @communities = split / /, $line[11];
            my $atomicaggregate = 0;
            $atomicaggregate = 1 if ($line[12] eq "AG");
            my $aggregator = $line[13];
            
            if (!($aggregator eq "")) {
                my @temp = split / /, scalar $aggregator;
                $nlri->aggregator([$temp[0], $temp[1]]);
            } else {
                $nlri->aggregator([]);
            }
            
            if ($is_ipv6_prefix) {
                $update->nlri([]);
                $update->withdrawn([]);
                $update->mp_unreach_nlri([]);
                $update->mp_reach_nlri([ @prefixes ]);
            } else {
                $update->withdrawn([]);
                $update->mp_unreach_nlri([]);
                $update->mp_reach_nlri([]);
                $update->nlri([ @prefixes ]);
            }
            
            $update->next_hop($next_hop);
            $update->as_path([ $brtas, $ASpath ]);
            $update->atomic_aggregate($atomicaggregate);
            $update->communities([@communities]);
            $update->local_pref($local_pref);
            $update->med($med);
            $update->origin($origin);
            
            # Send BGP announcement to all peers
            for ( my $i = 0; $i < $noofpeers ; $i = $i + 1) {
                $peers[$i]->update($update);
                usleep(10);
                if ($optv) {
                    my $t = $peers[$i]->peer_id();
                    print $ts-$ts_ref, " A: ";
                    foreach $prefix (@prefixes){
                        print "$prefix ";
                    }
                    print "\n";
                }
            }
            $count = $count + 1;
            
        } elsif ($cmd eq "W") {

            $update->next_hop($next_hop);
            
            if ($is_ipv6_prefix) {
                $update->withdrawn([]);
                $update->nlri([]);
                $update->mp_reach_nlri([]);
                $update->mp_unreach_nlri([ @prefixes ]);
            } else {
                $update->withdrawn([ @prefixes ]);
                $update->nlri([]);
                $update->mp_reach_nlri([]);
                $update->mp_unreach_nlri([]);
            }
            
            # Send BGP withdrawn to all peers 
            for ( my $i = 0; $i < $noofpeers ; $i = $i + 1) {
                $peers[$i]->update($update);
                usleep(10);
                if ($optv) {
                    my $t = $peers[$i]->peer_id();
                    print $ts-$ts_ref, " W: ";
                    foreach $prefix (@prefixes){
                        print "$prefix ";
                    }
                    print "\n";
                    
                }
            }
            $count = $count + 1;
        }
        
        @prefixes =();
        @line = @line_next;
    }; #process_routes

    if ($is_start eq 1) {
        while (my $cur_row = <$fh> || $lastline) {
            $process_routes -> ($cur_row);
        }
    } else {
        $update = Net::BGP::Update->new();
        $nlri = Net::BGP::NLRI->new();
        $aspath_obj = Net::BGP::ASPath->new([]);

        $count = 0;
        $nol = 0;
        $ts_old = 0;
        $time_old = gettimeofday();
        $ts_ref = 0;
        $count = 0;
        $aprefixes ="";
        @line = ();
        @prefixes = ();
        $lastline = 0;

        while (my ($index, $cur_row) =  each @pipe_buffer) {
            $process_routes -> ($cur_row);
        }
    }

}

sub my_timer_callback
{
    #my ($peer) = shift(@_);
    $notready = $notready - 1;
    if (!$notready) {
        if (!$connerror) {
            print "Start sending messages...\n";
            my $time_b = gettimeofday();
            # Open the dump file
            if (open($fh, '<:encoding(UTF-8)', $input_file)) {
                sending(1);
                close $fh;
            } else {
                die "Could not open BGPDump file '$input_file' $!";
            }
            $dtime = gettimeofday()- $time_b;
            print "Sending first messages completed...\n";
            print "no. of updates: $nol, time:$dtime (", int($nol/$dtime),"/s)\n";

            # for ( my $i = 0; $i < $noofpeers ; $i = $i + 1) {
                # $bgp->remove_peer($peers[$i]);
            # }
        } else {
            print "Error in one or more peer connection!\n";
            for ( my $i = 0; $i < $noofpeers ; $i = $i + 1) {
                $bgp->remove_peer($peers[$i]);
            }
        }
    } else {
        my $pipe_buffer = 0;
        my $rv = sysread($ph, $pipe_buffer, 65536); # read named pipe up to 64k

        if (!defined($rv) && $!{EAGAIN}) {
        } else {
            my $time_b = gettimeofday();
            my @dump_file = split '\n', $pipe_buffer;
            $nol = 0;
            if (open($fh, '<:encoding(UTF-8)', $dump_file[0])) {
                sending(1);
                close $fh;
            } else {
                warn "Could not open BGPDump file '$dump_file[0]' $!";
            }
            $dtime = gettimeofday()- $time_b;
            print "Sending updates completed...\n";
            print "no. of updates: $nol, time:$dtime (", int($nol/$dtime),"/s)\n";
        }
        $notready = 0;
    }
}

sub sub_open_callback
{
    my ($peer) = shift(@_);
    my $peerid =  $peer->peer_id();
    print "BGP connection is established with $peerid\n";
    $connerror = $connerror - 1;
}

sub sub_keepalive_callback
{
    my ($peer) = shift(@_);
    if ($optv) {
        my $peerid = $peer->peer_id();
        print "keepalive received from $peerid\n";
    }
}

sub sub_reset_callback
{
    my ($peer) = shift(@_);
    if ($optv) {
        print "The connection is reset\n";
    }
}

sub sub_notification_callback
{
    my ($peer) = shift(@_);
    my ($msg) = shift(@_);

    my $peerid =  $peer->peer_id();
    my $peeras =  $peer->peer_as();
    my $error_code = $msg->error_code();
    my $error_subcode = $msg->error_subcode();
    my $error_data = $msg->error_data();

    my $error_msg = $BGP_ERROR_CODES_SUBCODES{ $error_code }{ __NAME__ };
    print ("Notification received: type [$error_msg]");
    print (" subcode [" . $BGP_ERROR_CODES_SUBCODES{ $error_code }{ $error_subcode } . "]")	if ($error_subcode);
    print (" additional data: [" .  unpack ("H*", $error_data) . "]") 		if ($error_data);
    print ("\n");
}

sub sub_error_callback
{
    my ($peer) = shift(@_);
    my ($error) = shift(@_);

    my $error_code = $error->error_code();
    my $error_subcode = $error->error_subcode();
    my $error_data = $error->error_data();

    my $error_msg = $BGP_ERROR_CODES_SUBCODES{ $error_code }{ __NAME__ };
    print ("Error: $error_msg\n");

    if ($error_subcode) {
        print (" subcode " . $BGP_ERROR_CODES_SUBCODES{ $error_code }{ $error_subcode } . "\n");
    }
    print (" additional data: [" .  unpack ("H*", $error_data) . "]") if ($error_data);
    print ("\n");
    die("BRT terminated with an error\n");
}

sub check_asn
{
    my ($asnc_file) = shift(@_);
    my ($input_file) = shift(@_);
    my @asns;
    my %exist_asn;
    @exist_asn{@keys} = ();

    if (open(my $fasn, '<:encoding(UTF-8)', $asnc_file)){
        while (my $row = <$fasn>) {
            $row = substr($row, 0, length($row)-1, '');
            push @asns, $row.' ';
        }
    } else {
         die "Could not open AS-numbers file '$asnc_file' $!";
    }
    my $asnlen = scalar @asns;
 
    if (open(my $fin, '<:encoding(UTF-8)', $input_file)) {
        while (my $row = <$fin>) {
            # Split bgpdump fields 
            my @line = split '\|', $row;
            if ($line[2] eq 'A') {
                my $aspath = $line[6];
                $aspath =~ tr/,/\ /;
                $aspath =~ tr/{/\ /;
                $aspath =~ tr/}/\ /;
                $aspath .= ' ';
                for (my $i = 0; $i < $asnlen; $i += 1){
                    if (index($aspath, $asns[$i]) != -1) {
                        @exist_asn{$asns[$i]} = $asns[$i];
                    }
                }
            }
        }
    } else {
        die "Could not open BGPDump file '$input_file' $!";
    }
    
    
    if (scalar %exist_asn) {
        print "Exist AS numbers = [ ";
        foreach my $asn (keys %exist_asn) {
            print "$asn ";
        }
        print "]\n";
        return 1;
    } else {
        return 0;
    }
    
}

sub sub_update_callback
{
}

# The main code
my ($tpeerip, $tbrtip);

#get command line arguments
GetOptions( 
    'help'  => \$opthelp, 
    'ipv6'  => \$optipv6,
    'v'     => \$optv,
    'f=s'   => \$input_file,
    'u=s'   => \$named_pipe,
    'brtas=s'   => \$brtas,
    'brtip=s'   => \$brtip,
    'brtipv6=s' => \$brtipv6,
    'peerip=s'  => \$peerip,
    'peeripv6=s'    => \$peeripv6,
    'peeras=s'  => \$peeras,
    'multipeer=s'   => \$multipeer_file,
    'c=s'   => \$asnc_file,
    'l' => \$optlisten,
    't' => \$opttime,
 );

if ($opthelp) {
    die($help);
}

if (!($brtas && $input_file)) {
    print "Please provide -brtas and -f <Filename>!\n";
    die($help);
}

if (!($input_file eq '') && !($asnc_file eq '')) {
    print "Checking AS number existnce in the topology...\n";
    if (check_asn($asnc_file, $input_file)) {
        print("Error: One AS number or more exist in your topology!\n");
        exit(1);
    }
}

if (!($named_pipe eq '')) {
    sysopen($ph, $named_pipe, O_NONBLOCK|O_RDWR)
        or die "Can't open named pipe: $!\n";
}

$bgp  = Net::BGP::Process->new();

if (!$multipeer_file eq '') {
    # connect to multiple peers
    my $i = 0;
    if (open(my $fhm, '<:encoding(UTF-8)', $multipeer_file)) {
        while (my $string = <$fhm>) {
            print "$string\n" if ($optv);
            $ret = GetOptionsFromString($string,
                'ipv6'  => \$optipv6,
                'brtip=s'   => \$brtip,
                'brtipv6=s' => \$brtipv6,
                'peerip=s'  => \$peerip,
                'peeripv6=s'    => \$peeripv6,
                'peeras=s'  => \$peeras,
            );
            if ($optipv6) {
                # Use IPv6 for peer connection 
                $tpeerip = $peeripv6;
                $tbrtip = $brtipv6;
            } else {
                # Use IPv4 for peer connection 
                $tpeerip = $peerip;
                $tbrtip = $brtip;
            }
            
            if (!($tbrtip && $peeras && $tpeerip)) {
                print "Please provide brtip, peeras and peerip in multipeer file!\n";
                exit(1);
            }

            $peers[$i] = Net::BGP::Peer->new(
                    Start    => 0,
                    ThisID   => $tbrtip,
                    ThisAS   => $brtas,
                    PeerID   => $tpeerip,
                    PeerAS   => $peeras,
                    HoldTime => $holdtime,
                    KeepAliveTime => $keepalive,
                    Listen  => $optlisten,
                    KeepaliveCallback    => \&sub_keepalive_callback,
                    UpdateCallback       => \&sub_update_callback,
                    NotificationCallback => \&sub_notification_callback,
                    ErrorCallback        => \&sub_error_callback,
                    OpenCallback        => \&sub_open_callback,
                    ResetCallback        => \&sub_reset_callback,
            );

            $bgp->add_peer($peers[$i]);
            $peers[$i]->add_timer(\&my_timer_callback, 2);
            $peers[$i]->start();
            $i = $i + 1;
        }
        $notready = $i;
        $connerror = $i;
        $noofpeers = $i;
    } else { 
        die "Could not open file '$multipeer_file' $!";
    }
} else {

    # connect to one peer only
    if ($optipv6) {
        #use IPv6 for peer connection 
        $tpeerip = $peeripv6;
        $tbrtip = $brtipv6;
    } else {
        #use IPv4 for peer connection 
        $tpeerip = $peerip;
        $tbrtip = $brtip;
    }

    if (!($tbrtip && $peeras && $tpeerip)) {
        print "Please provide brtip, peeras and peerip!\n";
        exit(1);
    }
    $peers[0] = Net::BGP::Peer->new(
            Start    => 0,
            ThisID   => $tbrtip,
            ThisAS   => $brtas,
            PeerID   => $tpeerip,
            PeerAS   => $peeras,
            HoldTime => $holdtime,
            KeepAliveTime => $keepalive,
            Listen => $optlisten,
            KeepaliveCallback   => \&sub_keepalive_callback,
            UpdateCallback  => \&sub_update_callback,
            NotificationCallback    => \&sub_notification_callback,
            ErrorCallback   => \&sub_error_callback,
            OpenCallback    => \&sub_open_callback,
            ResetCallback   => \&sub_reset_callback,
    );

    $bgp->add_peer($peers[0]);
    $peers[0]->add_timer(\&my_timer_callback, 2);
    $peers[0]->start();
}

$bgp->event_loop();
