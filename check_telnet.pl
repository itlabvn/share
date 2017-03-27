#!/usr/bin/perl

# FILE: check_telnet.pl
# SYNOPSIS: nagios-compatible script to check telnet port.  Supports expect-like 
# passing of commands/arguments and returning data.
# RESPONSIBLE_PARTY: eli
# LICENSE: GPL, Copyright 2006 Eli Stair <eli.stair {at} gmail {dot} com>,
#          2014 M Milligan <ammilligan {at} gmail {dot} com>
# Modifications:
# 2014-01-14 M Milligan Replaced hostmatch() sub with checkmatch() sub to 
#            match text in the banner. This sub does more checking of the banner
#            by examining ALL elements of @banner. It will only fail if NO
#            elements of banner match the text provided in the -M flag.
#
#            Removed unused sub netdev(). 
#
#            More robust error handling in hostconnect().
# 2014-10-06 M Milligan Updated checkmatch() to wrap the text to match ($match) in
#            forward slashes.
#            
#            Added timeout switch (-T time_in_seconds).
#
#            Removed "Banner text" output.

use strict;

use Getopt::Long;
use Net::Telnet ();

########################################################################
# begin program flow:
# get cmdline args and parse them:

our ($telnet, $host, $port, $match, $cmd, $user, $password, $nagios_returnval, $timeout);
our $NAGIOS_OK = 0;
our $NAGIOS_UNKNOWN = 3;
our $NAGIOS_CRITICAL = 2;

my $args_ok = processargs();

if ($args_ok) {
    my $connected = hostconnect();

    if ( $connected) {
        if ($match) {
            &checkmatch;
        } elsif ($cmd) {
            &runcmd;
        }
    } else {
        print "CRITICAL: Can't connect to port $port on $host!\n";
        $nagios_returnval = $NAGIOS_CRITICAL;
    }
} else {
    print "UNKNOWN: Invalid arguments\n";
    $nagios_returnval = $NAGIOS_UNKNOWN;
}

cleanup() ;
return $nagios_returnval;

########################################################################

### FUNC: getargs
sub processargs() {

my $exitval = 1;

GetOptions (
    "H|host=s" => \$host,
    "P|port=i" => \$port, 
    "C|command=s" => \$cmd, 
    "M|match=s" => \$match,
    "T|timeout=i" => \$timeout,
    "user=s" => \$user,
    "password=s" => \$password,
);

# quick cmdarg lint:
unless ($host) { &cmdusage ; $exitval = -1 };

$port = "23" unless defined($port);

$timeout = "5" unless defined($timeout);

if ($cmd) {
  unless ($user && $password) { 
    &cmdusage;
    $exitval = -1;
  }
}

return $exitval;
}

### FUNC: cmdusage
sub cmdusage() {
    print "\n";
    print "\t-H\t hostname/IP: of host to connect to gmetad/gmond on ","\n";
    print "\t-P\t Port: to connect to and retrieve XML ","\n";
    print "\t-C\t Command: command to execute when telnet connects \n";
    print "\t-M\t Match: String to match";
    print "\t-T\t Timeout: Time, in seconds, to wait for test to complete";
    print "\n\n";

}
### /FUNC: cmdusage


### FUNC: hostconnect
sub hostconnect() {

my $exitval = 1; # Assume connect succeeds
$telnet = new Net::Telnet (
Telnetmode => 0,
Timeout => 5,
);

# set up object
unless ($telnet->open(Host => $host, Port => $port, ErrMode => "return")) {
  $exitval = 0;
}

return $exitval;
} #/sub hostconnect


### FUNC: checkmatch
sub checkmatch() {
my $exitval = $NAGIOS_CRITICAL; # Assume match fails
$telnet->print("");
my $banner = $telnet->waitfor(Match => "/".$match."/", Errmode => "return", Timeout => $timeout);

if ( $banner ) {
  $exitval = $NAGIOS_OK;
}

if ( ! $exitval ) {
  print "OK: regex-string ($match) matches login banner.\n";
} else {
  print "CRITICAL: regex-string ($match) did not match login banner.\n";
}

$telnet->close;
$nagios_returnval = $exitval;
exit $exitval;

} #/sub checkmatch

### FUNC: cleanup 
sub cleanup() {
$telnet->close;
exit 0;
} #/cleanup

sub runcmd() {
$telnet->print("");
unless ($telnet->login($user, $password)) {
    print "CRITICAL: Can't connect to $host as user ($user)! \n";
    exit $NAGIOS_CRITICAL;
}

my @cmdout = ($telnet->cmd($cmd));
foreach (@cmdout) {
    print $_;
}

#this unsuccessful (timing out) logout clears the socket... dunno
$telnet->print("logout");
$telnet->close;
} 


