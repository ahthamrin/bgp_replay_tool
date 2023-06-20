-------------------------------------------------------------------------------
School of Software and Electrical Engineering,
Swinburne University of Technology,
Melbourne, Australia

June, 2017
bgp-features-0.2: BGP features extractor 

Author: Rasool Al-Saadi <ralsaadi@swin.edu.au>
-------------------------------------------------------------------------------

1. OVERVIEW
------------
bgp-features-0.2 is a Perl script to calculate different BGP features. These 
features include number of BGP announcements, number of BGP withdrawals, number
of BGP announcements and withdrawals, average length of AS-PATH and maximum
AS-PATH length.
These BGP features are calculated every second.


2. USAGE
---------
Execute the script as follows:

    perl bgp-features-0.2.pl -f <filename>


3. SCRIPT OUTPUT
------------------
The output of this script is organized as a table where each row represents
BGP features for one second. The features and the sequence of them are as flow:
    1- volume --> Total number of BGP announcements and withdrawals.
    2- announcements --> Number of BGP announcements per second
    3- IPv4 announcements --> Number of IPv4 BGP announcements.
    4- IPv6 announcements --> Number of IPv6 BGP announcements.
    5- withdrawals --> Number of BGP withdrawals.
    6- IPv4 withdrawals --> Number of IPv4 BGP withdrawals.
    7- IPv6withdrawals --> Number of IPv6 BGP withdrawals.
    8- max-as-path --> maximum AS-PATH length.
    9- average-as-path --> Average length of AS-PATH.


4. LICENCE
-----------
This tool is released under a new BSD License. For more details
please refer to the included source files.


5. ACKNOWLEDGEMENTS
-------------------- 
The development of BRT v0.2 has been made possible in part by
"APNIC Internet Operations Research Grant" under the ISIF
Asia 2016 grant scheme.
