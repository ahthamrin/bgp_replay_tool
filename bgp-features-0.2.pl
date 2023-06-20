#!/usr/bin/perl
###############################################################################
# Copyright (c) 2017, School of Software and Electrical Engineering
# Swinburne University of Technology, Melbourne, Australia
###############################################################################
# BGP Feature extraction script
#
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
# Please e-mail any bugs, suggestions and feature requests to
#    <ralsaadi@swin.edu.au>
###############################################################################

# Import the necessary modules
use Getopt::Long;
use Getopt::Long qw(GetOptionsFromString);

my $help = <<EOF;
BGP Features Extraction Tool.

usage:
 bgp-features.pl
  -f <Filename>	# BGP update file in human readable with Unix format
				#(bgpdump -m option)
  [-help]	# Display BRT tool help
EOF

my $input_file;
my $nol = 0;
my $total_bgp = 0;
my %features = ('bgp_volume' => 0, 'announ' => 0, 'withdrawal' => 0, 
                'ipv4_announ' => 0, 'ipv6_announ' => 0, 'ipv4_withdrowal' => 0,
                'ipv6_withdrowal' => 0, 'max_path' => 0, 'avg_path' => 0,
                );

sub start
{
    my $ts_old = 0;
    my $total_aspath_len = 0;
    my $lastline = 0;

    if (open(my $fh, '<:encoding(UTF-8)', $input_file)) {
        while (my $row = <$fh> || $lastline) {
            my @line = split '\|', $row;
            my $ts = $line[1];
            
            if ((($ts_old != 0) && ($ts != $ts_old)) || $lastline) {
            
                $features{'announ'} = $features{'ipv4_announ'} +
                    $features{'ipv6_announ'};
                $features{'withdrawal'} = $features{'ipv4_withdrowal'} +
                    $features{'ipv6_withdrowal'};
                $features{'bgp_volume'} += $features{'announ'} +
                    $features{'withdrawal'};
                $total_bgp += $features{'bgp_volume'};
                $features{'avg_path'} =
                    int($total_aspath_len / $features{'announ'}) if ($features{'announ'});

                print "$features{'bgp_volume'} $features{'announ'} ";
                print "$features{'withdrawal'} $features{'ipv4_announ'} ";
                print "$features{'ipv6_announ'} $features{'ipv4_withdrowal'} ";
                print "$features{'ipv6_withdrowal'} ";
                print "$features{'max_path'} $features{'avg_path'}\n";

                %features = ('bgp_volume' => 0, 'announ' => 0, 'withdrawal' => 0, 
                    'ipv4_announ' => 0, 'ipv6_announ' => 0, 'ipv4_withdrowal' => 0,
                    'ipv6_withdrowal' => 0, 'max_path' => 0, 'avg_path' => 0,
                );
                
                $total_aspath_len = 0;

                # print zeros for missing seconds
                if ($ts - $ts_old > 1) {
                    for ($i = $ts_old + 1; $i < $ts; $i += 1) {
                        print "$features{'bgp_volume'} $features{'announ'} ";
                        print "$features{'withdrawal'} $features{'ipv4_announ'} ";
                        print "$features{'ipv6_announ'} $features{'ipv4_withdrowal'} ";
                        print "$features{'ipv6_withdrowal'} ";
                        print "$features{'max_path'} $features{'avg_path'}\n";
                    }
                }
            }

            if ($lastline) {
                last;
            } else {
                $lastline = eof($fh);
            }
            $nol += 1;
            
            $ts_old = $ts;
            
            my $cmd = $line[2];            
            # We don't care about AS_IP, AS and real next_hop
            #my $thisASIP = $line[3];
            #my $thisAS = $line[4];
            #my $next_hop = $line[8];

            my $is_ipv6_prefix = 0;
            $is_ipv6_prefix = 1 if ( $line[5] =~ /\:/);
            
            
            if ($cmd eq "A" || $cmd eq "B" ) {
                
                
                my $ASpath = $line[6];
                # my $origin = $line[7];
                # my $local_pref = $line[9];
                # my $med = $line[10];
                # my $communities = $line[11];
                # my $atomicaggregate = 0;
                # my $atomicaggregate = 1 if ($line[12] eq "AG");
                # my $aggregator = $line[13];
                
                $path_len = 1;
                for ($i = 1; $i <= length($ASpath); $i += 1){
                    $ch = substr($ASpath, $i, 1);
                    last if ($ch eq "{");
                    $path_len +=1 if ($ch eq " ");
                }
                $total_aspath_len += $path_len;
                $features{'max_path'} = $path_len if ($path_len > $features{'max_path'});

                if ($is_ipv6_prefix) {
                    $features{'ipv6_announ'} += 1;
                } else {
                    $features{'ipv4_announ'} += 1;
                }
                
            } elsif ($cmd eq "W") {
            
                if ($is_ipv6_prefix) {
                    $features{'ipv6_withdrowal'} += 1;
                } else {
                    $features{'ipv4_withdrowal'} += 1;
                }
                
            } else {
                 $features{'bgp_volume'}  += 1;
            }
            
        } #while
    } else { 
        die "Could not open BGPDump file '$input_file' $!";
    }
}

#get command line arguments
GetOptions( 
    'help' => \$opthelp, 
    'f=s' => \$input_file,
);
 
 if ($opthelp) {
    die($help);
}

if (!$input_file) {
    print "Please provide -f <Filename>!\n";
    die($help);
}

start();

