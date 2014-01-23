#!/usr/bin/perl -w
#-------------------------------------------------------------------------------
# Author:	Peter McGowan
#               Copyright 2008 Peter McGowan 

#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.

#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.

#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Description:  check_sar.pl Nagios plug-in to monitor sar data
#
# Version:	0.4
#
# Revision History
#
# Original		0.1					PEMcG	Original release
#				0.2	
#				0.3		26-Aug-11	PEMcG	Changed -d switch to silently add -p so that devices can be specified as
#											friendly names under /dev/ rather than device major-minor numbers
#				0.4		10-Aug-12	PEMcG	Bugfix of %ERRORS

#-------------------------------------------------------------------------------

my $MyVersion='0.3';
use strict;
use Getopt::Long;
Getopt::Long::Configure('bundling');
sub print_usage;

my $TIMEOUT = 15;
my %ERRORS = (
	'OK' => 0,
	'WARNING' => 1,
	'CRITICAL' => 2,
	'UNKNOWN' => 3,
	'DEPENDENT' => 4);
my $ReturnCode;
my $PROGNAME="check_sar";

# sar monitoring parameters are as follows:
#
# sar -c : process creation
#	'proc/s' = Processes Created/Sec
#
# sar -w : Context switches
#	'cswch/s' = Context Switches/Sec
#
# sar -u : CPU stats
#
#	'%user' = % User Level
#	'%nice' = % User Level (nice)
#	'%system' => "% System Level
#	'%iowait' => "% Idle Waiting on I/O (IOwait)
#	'%steal' => "% Time in Involuntary Wait
#	'%idle' => "% Idle
#      	'%utilisation' => "% Utilisation
#
# sar -I SUM : Total interrupts
#
#	'intr/s' = Interrupts/Sec
#
# sar -W : Swapping stats
#
#	'pswpin/s' = Pages Swapped In/Sec
#      	'pswpout/s' = Pages Swapped Out/Sec
#
# sar -b : I/O and transfer rate stats
#
#      	'tps' = Transfers/Sec
#      	'rtps' = Read Transfers/Sec
#      	'wtps' = Write Transfers/Sec
#      	'bread/s' = Blocks Read/Sec
#      	'bwrtn/s' = Blocks Written/Sec
#
# sar -R : Memory stats
#
#      	'frmpg/s' = Memory Pages Freed/Sec
#      	'shmpg/s' = Add'l Pages Shared/Sec
#      	'bufpg/s' = Add'l Buffer Pages/Sec
#      	'campg/s' = Add'l Cached Pages/Sec
#
# sar -y : TTY device activity
#
#      	'rcvin/s' = Serial Line Receive Ints/Sec
#      	'xmtin/s' = Serial Line Transmit Ints/Sec
#      	'framerr/s' = Serial Line Frame Errors/Sec
#      	'prtyerr/s' = Serial Line Parity Errors/Sec
#      	'brk/s' = Serial Line Breaks/Sec
#      	'ovrun/s' = Serial Line Overruns/Sec
#
# sar -n DEV : Network device stats
#
#      	'rxpck/s' = Pkts Rcv'd/Sec
#      	'txpck/s' = Pkts Trans'd/Sec
#      	'rxbyt/s' = Bytes Rcv'd/Sec
#      	'txbyt/s' = Bytes Trans'd/Sec
#      	'rxcmp/s' = Compressed Pkts Rcv'd/Sec
#      	'txcmp/s' = Compressed Pkts Trans'd/Sec
#      	'rxmcst/s' = Multicast Pkts Rcv'd/Sec
#
# sar -n EDEV : Network device errors
#
#      	'rxerr/s' = Bad Pkts Rcv'd/Sec
#      	'txerr/s' = Transmit Errors/Sec
#      	'coll/s' = Collisions/Sec
#      	'rxdrop/s' = Receive Pkts Dropped/Sec
#      	'txdrop/s' = Transmit Pkts Dropped/Sec
#      	'txcarr/s' = Transmit Carrier Errors/Sec
#      	'rxfram/s' = Receive Frame Alignment Errors/Sec
#      	'rxfifo/s' = Receive FIFO Overrun Errors/Sec
#      	'txfifo/s' = Transmit FIFO Overrun Errors/Sec
#
# sar -d : I/O activity for each block device
#
#      	'rd_sec/s' = Sectors Read/Sec
#      	'wr_sec/s' = Sectors Written/Sec
#      	'avgrq-sz' = Average Request Size (Sectors)
#      	'avgqu-sz' = Average Queue Length
#      	'await' = Average I/O Time inc Wait(ms)
#      	'svctm' = Average I/O Service Time (ms)
#      	'%util' = % Bandwidth Utilisation
#
# sar -n NFS : NFS client activity
#
#      	'call/s' = RPC Requests Made/Sec
#      	'retrans/s' = RPC Retransmitted Requests Made/Sec
#      	'read/s' = RPC Read Requests Made/Sec
#      	'write/s' = RPC Write Requests Made/Sec
#      	'access/s' = RPC Access Requests Made/Sec
#      	'getatt/s' = RPC Getattr Requests Made/Sec
#
# sar -n NFSD : NFS server activity
#
#      	'scall/s' = RPC Requests Received/Sec
#      	'badcall/s' = Bad RPC Requests Received/Sec
#      	'packet/s' = Network Packets Received/Sec
#      	'udp/s' = UDP Packets Received/Sec
#      	'tcp/s' = TCP Packets Received/Sec
#      	'hit/s' = Reply Cache Hits/Sec
#      	'miss/s' = Reply Cache Misses/Sec
#      	'sread/s' = RPC Read Calls Received/Sec
#      	'swrite/s' = RPC Write Calls Received/Sec
#      	'saccess/s' = RPC Access Calls Received/Sec
#      	'sgetatt/s' = RPC Getattr Calls Received/Sec
#
# sar -B : Paging stats
#
#      	'pgpgin/s' = KB Paged In/Sec
#      	'pgpgout/s' = KB Paged Out/Sec
#      	'fault/s' = Total Page Faults/Sec
#      	'majflt/s' = Major Faults/Sec
#
# sar -r : Memory & swap space utilisation stats
#
#      	'kbmemfree' = Free Memory KB
#      	'kbmemused' = Used Memory KB
#      	'%memused' = % Memory Used
#      	'kbmemshrd' = Shared Memory KB
#      	'kbbuffers' = Kernel Buffers KB
#      	'kbcached' = Data Cache KB
#      	'kbswpfree' = Free Swap Space KB
#      	'kbswpused' = Used Swap Space KB
#      	'%swpused' = % Swap Used
#      	'kbswpcad' = Cached Swap KB
#
# sar -v : Files, inodes & other kernel tables
#
#      	'dentunusd' = Unused Directory Cache Entries
#      	'file-sz' = Used File Handles
#      	'%file-sz' = % Used File Handles
#      	'inode-sz' = Used Inode Handlers
#      	'super-sz' = Super Block Handlers
#      	'%super-sz' = % Allocated Super Block Handlers
#      	'dquot-sz' = Allocated Disc Quota Entries
#      	'%dquot-sz' = % Allocated Disc Quota Entries
#      	'rtsig-sz' = Queued RT Signals
#      	'%rtsig-sz' = % Queued RT Signals
#
# sar -n SOCK : Socket stats
#
#      	'totsck' = Total Used Sockets
#      	'tcpsck' = TCP Sockets in Use
#      	'udpsck' = UDP Sockets in Use
#      	'rawsck' = Raw Sockets in Use
#      	'ip-frag' = IP Fragments in Use
#
# sar -q : Queue length & load average
#
#      	'runq-sz' = Run Queue Length
#      	'plist-sz' = No. of Processes in List
#      	'ldavg-1' = System Load Avg. Last Min.
#      	'ldavg-5' = System Load Avg. Last 5 Mins.
#      	'ldavg-15' = System Load Avg. Last 15 Mins.
#
# sar -x ALL : Process stats
#
#      	'minflt/s' = Minor Faults/Sec
#      	'majflt/s' = Major Faults/Sec
#      	'nswap/s' = Process Pages Swapped Out/Sec
#
# sar -X ALL : Child process stats
#     	
#      	'cminflt/s' = Child Process Minor Faults/Sec
#      	'cmajflt/s' = Child Process Major Faults/Sec
#      	'%cuser' = Child Process % User Level
#      	'%csystem' = Child Process % System Level
#      	'cnswap/s' = Child Process Pages Swapped Out/Sec

#
# Chack that sar is installed before we do anything else
#
my $SAR;
if (system('which sar &> /dev/null')){
	print "sar does not seem to be installed on this system\n";
	exit $ERRORS{'UNKNOWN'};
} else {
	$SAR = `which sar`;
	chomp $SAR;
}
 
our ($Version, $Help, $WarningValue, $CriticalValue, $Timeout, $SarSwitch, $SarValue, $SwitchQualifier, $Device, $SarValueOut);

GetOptions(
	"V|version"      => \$Version,
	"h|help"         => \$Help,
	"w|warning=f"    => \$WarningValue,
	"c|critical=f"   => \$CriticalValue,
	"t|timeout=i"    => \$Timeout,
	"s|sarswitch=s"  => \$SarSwitch,
	"l|sarvalue=s"   => \$SarValue,
	"q|qualifier=s"  => \$SwitchQualifier,
	"d|device=s"     => \$Device,
	);
#
# Process the easy arguments
#
if (defined $Version) {
	print "Version: $MyVersion\n";
	exit $ERRORS{'OK'};
}
if (defined $Help) {
	print_usage();
	exit $ERRORS{'OK'};
}
#
# Just in case of problems, let's not hang Nagios
#
$SIG{'ALRM'} = sub {
	print "UNKNOWN - Plugin Timed out\n";
	exit $ERRORS{"UNKNOWN"};
};
if (defined $Timeout) {
	$TIMEOUT = $Timeout;
}
alarm($TIMEOUT);
#
# Sanity check the other arguments and argument combinations
#
if (!defined $WarningValue) {
	print "\n*** Error - Must specify a warning value ***\n";
	exit $ERRORS{'UNKNOWN'};
}

if (!defined $CriticalValue) {
	print "\n*** Error - Must specify a critical value ***\n";
	exit $ERRORS{'UNKNOWN'};
}

if (!defined $SarSwitch) {
	print "\n*** Error - Must specify a sar switch to retrieve data for ***\n";
	exit $ERRORS{'UNKNOWN'};
}

if (($SarSwitch =~ /[nPIxX]/) && !(defined $SwitchQualifier)) {
	print "\n*** Error - Must specifiy a qualifier with this switch ***\n";
	print "\nPossible qualifiers are:\n";
	print "	   -I { <irq> | SUM | ALL | XALL }\n";
	print "	   -P { <cpu> | ALL }\n";
	print "	   -n { DEV | EDEV | NFS | NFSD | SOCK | ALL }\n";
	print "	   -x { <pid> | SELF | ALL }\n";
	print "	   -X { <pid> | SELF | ALL }\n";
	exit $ERRORS{'UNKNOWN'};
}

if (!defined $SwitchQualifier) {
	$SwitchQualifier = "";
}

if (($SarSwitch =~ /[nd]/) && !(defined $Device)) {
	print "\n*** Error - Must specifiy a device with this switch ***\n";
	print "\nPossible devices are:\n";
	print "	   -n: eth0, bond0, lo, sit0, etc.\n";
	print "	   -d: device name under /dev/ eg 'sda' or 'cciss/c1dop1'\n";
	exit $ERRORS{'UNKNOWN'};
}

if (!defined $Device) {
	$Device = "";
}

if (!defined $SarValue) {
	print "\n*** Error - Must specify a sar value to compare warning/critical against ***\n";
	print "\nPossible values for -$SarSwitch $SwitchQualifier :  ";
	foreach (`$SAR -$SarSwitch $SwitchQualifier 2>/dev/null`) {
		if (/^\d{2}:\d{2}:\d{2}/){
			if (!/RESTART/){
				my @Headings = split;
				foreach my $Heading (@Headings[2..$#Headings]){
					next if ($Heading =~ /CPU|INTR|TTY|IFACE/);
					print "$Heading ";
				}
				print "\n";
				last;
			}
		}
	}
	exit $ERRORS{'UNKNOWN'};	
}
#
# Read the line of headings
#
my ($Heading, @Headings);
foreach (`$SAR -$SarSwitch $SwitchQualifier 2>/dev/null`) {
	if (/^\d{2}:\d{2}:\d{2}/){
		if (!/RESTART/){
			@Headings = split;
			last;
		}
	}
}
if (scalar(@Headings) == 0) {
	print "Either \'$SwitchQualifier\' is an invalid qualifier, or no sar values have been logged yet\n";
	$ReturnCode = $ERRORS{UNKNOWN};
	exit $ReturnCode;
}
my $ValueIndex = 0;
my $ValidValue = 0;
foreach $Heading (@Headings){
	if ($Heading eq $SarValue){
		$ValidValue = 1;
		last;
	}
	$ValueIndex++;
}
if (!$ValidValue){
	print "$SarValue does not seem to be a valid sar value\n";
	exit $ERRORS{'UNKNOWN'};
}

my ($CommandString, @SarReturnLine, $TargetValue);
#
# Build up command line
#
SWITCH: {
	if ($SarSwitch =~ /[bBcpqrRtuvwWy]/) {$CommandString = "$SAR -$SarSwitch "; last SWITCH;}
	if ($SarSwitch =~ /[PIxX]/) {$CommandString = "$SAR -$SarSwitch $SwitchQualifier"; last SWITCH;}
	if ($SarSwitch =~ /[n]/) {$CommandString = "$SAR -$SarSwitch $SwitchQualifier | grep  $Device"; last SWITCH;}
	if ($SarSwitch =~ /d/) {$CommandString = "$SAR -dp | grep  $Device "; last SWITCH;}
	print "Unrecognised sar switch: $SarSwitch\n";
	exit;
}
$CommandString .= "| grep -v Average | tail -1";
#
# Submit the sar command and retrieve the output
#
@SarReturnLine = split(/\s+/, `$CommandString`);
$TargetValue = $SarReturnLine[$ValueIndex];
if (!defined $TargetValue){
	exit $ERRORS{'UNKNOWN'};
}
#
# Pretty up the switch spacings for the printed output line
#
if ($SwitchQualifier ne ""){
	$SwitchQualifier = " " . $SwitchQualifier;
}
if ($Device ne ""){
	$Device = " " . $Device;
}
$SarValueOut = " " . $SarValue;
#
# Calculate our return status - working out if we should be looking for a maximum or minimum threshold
#
if ($CriticalValue >= $WarningValue){
	if ($TargetValue >= $CriticalValue){
		$ReturnCode = $ERRORS{'CRITICAL'};
		print "SAR CRITICAL: ";
	} elsif ($TargetValue >= $WarningValue){
		$ReturnCode = $ERRORS{'WARNING'};
		print "SAR WARNING: ";
	} else {
		$ReturnCode = $ERRORS{'OK'};
		print "SAR OK: ";
	}
} elsif ($CriticalValue < $WarningValue){
	if ($TargetValue <= $CriticalValue){
		$ReturnCode = $ERRORS{'CRITICAL'};
		print "SAR CRITICAL: ";
	} elsif ($TargetValue <= $WarningValue){
		$ReturnCode = $ERRORS{'WARNING'};
		print "SAR WARNING: ";
	} else {
		$ReturnCode = $ERRORS{'OK'};
		print "SAR OK: ";
	}
}
print "sar -$SarSwitch$SwitchQualifier$Device$SarValueOut = $TargetValue|$SarValue=$TargetValue;$WarningValue;$CriticalValue\n";
exit $ReturnCode;


sub print_usage () {
	print "\nUsage:\n";
	print "  $PROGNAME -w <INTEGER> -c <INTEGER> [-t TIMEOUT] -s SAR_SWITCH -l SAR_VALUE [-q QUALIFIER] [-d DEVICE]\n";
	print "  $PROGNAME [-h | --help]\n";
	print "  $PROGNAME [-V | --version]\n";
	print "\nOptions:\n";
	print "  -h, --help\n";
	print "     Print detailed help screen\n";
	print "  -V, --version\n";
	print "     Print version information\n";
	print "  -t, --timeout\n";
	print "     Optional timeout (seconds) for Nagios\n";
	print "  -w, --warning\n";
	print "     Value above which a warning will be returned\n";
	print "  -c, --critical\n";
	print "     Value above which a critical will be returned\n";
	print "  -s, --sarswitch\n";
	print "     sar switch to return data from (e.g. 'u' for CPU stats, 'W' for swapping stats etc (see man sar))\n";
	print "  -l, --sarvalue\n";
	print "     sar value to measure against (e.q. '%iowait' might be appropriate for a 'u' sar switch)\n";
	print "  -q, --qualifier\n";
	print "     qualifier for sar switch (e.q. 'n' needs one of 'DEV','NFS', etc)\n";
	print "  -d, --device\n";
	print "     device to parse from sar output, e.g. sar -n DEV might require 'eth0'; sar -d needs a device name under /dev/ such as 'sda' or 'cciss/c0d0'\n\n";
	print "     Reminder - sar options are:\n";
	print "	      [ -A ] [ -b ] [ -B ] [ -c ] [ -d ] [ -p ] [ -q ] [ -r ]\n";
	print "	      [ -R ] [ -t ] [ -u ] [ -v ] [ -V ] [ -w ] [ -W ] [ -y ]\n";
	print "	      [ -I { <irq> | SUM | ALL | XALL } ] [ -P { <cpu> | ALL } ]\n";
	print "	      [ -n { DEV | EDEV | NFS | NFSD | SOCK | ALL } ]\n";
	print "	      [ -x { <pid> | SELF | ALL } ] [ -X { <pid> | SELF | ALL } ]\n";
}



