#!/usr/bin/perl

##################################################################################
##################################################################################
#######################  Made by Tytus Kurek on October 2012  ####################
##################################################################################
##################################################################################
####  This is a Nagios Plugin destined to check the status and bandwidth of   ####
####                         Cisco device interfaces.                         ####
##################################################################################
##################################################################################

use strict;
use vars qw($community $critical $interface $IP $warning);

use Getopt::Long;
use Pod::Usage;

# Subroutines execution

getParameters ();
checkInterfaceStatus ();

# Subroutines definition

sub checkInterfaceBandwidth	# Checks if the bandwidth exceeds the threshold
{
	my $output;
	my $code; 

	if ($_[0] < $warning)
	{
		$output = "$_[1] usage of $interface interface: $_[0] Mb/s.";
		$code = 0;
	}

	elsif (($_[0] >= $warning) && ($_[0] < $critical))
	{
		$output = "$_[1] usage of $interface interface: $_[0] Mb/s exceeds threshold of $warning Mb/s.";
		$code = 1;
	}

	else
	{
		$output = "$_[1] usage of $interface interface: $_[0] Mb/s exceeds threshold of $critical Mb/s.";
		$code = 2;
	}

	return ($output, $code);
}

sub checkInterfaceStatus ()	# Checks interface status via SNMP
{
	my $ifAdminStatus = '.1.7';
	my $ifDescr = '.1.2';
	my $ifInOctets = '.1.10';
	my $ifOperStatus = '.1.8';
	my $ifOutOctets = '.1.16';
	my $OID = '1.3.6.1.2.1.2.2';
	my $version = '2c';

	my $command = "/usr/bin/snmpwalk -v $version -c $community $IP $OID 2>&1";
        my $result = `$command`;

        if ($result =~ m/^Timeout.*$/)
        {
                my $output = "UNKNOWN! No SNMP response from $IP.";
                my $code = 3;
                exitScript ($output, $code);
        }

	my $extendedOID = $OID . $ifDescr;
	$command = "/usr/bin/snmpwalk -v $version -c $community $IP $extendedOID";
	$result = `$command`;
	$result =~ m/IF-MIB::ifDescr\.(\d+)\s=\s.*$interface.*/;
	my $ifNumber = $1;

	$extendedOID = $OID . $ifAdminStatus . ".$ifNumber";
	$command = "/usr/bin/snmpget -v $version -c $community $IP $extendedOID";
	$result = `$command`;

	if ($result !~ m/^IF-MIB::ifAdminStatus.$ifNumber\s=\sINTEGER:\sup\(1\)$/)
	{
		my $output = "CRITICAL! Interface $interface is in administrative shutdown mode.";
		my $code = 2;
		exitScript ($output, $code);
	}

	$extendedOID = $OID . $ifOperStatus . ".$ifNumber";
	$command = "/usr/bin/snmpget -v $version -c $community $IP $extendedOID";
	$result = `$command`;

	if ($result !~ m/^IF-MIB::ifOperStatus.$ifNumber\s=\sINTEGER:\sup\(1\)$/)
	{
		my $output = "CRITICAL! Interface $interface is down.";
		my $code = 2;
		exitScript ($output, $code);
	}

	my $inBandwidth = countInterfaceBandwidth ($OID, $ifInOctets, $ifNumber, $version);
	my $outBandwidth = countInterfaceBandwidth ($OID, $ifOutOctets, $ifNumber, $version);

	if (($warning ne '') && ($critical ne ''))
	{
		my ($inOutput, $inCode) = checkInterfaceBandwidth ($inBandwidth, 'Inbound');
		my ($outOutput, $outCode) = checkInterfaceBandwidth ($outBandwidth, 'Outbound');

		my $output;
		my $code;

		$inBandwidth = $inBandwidth * 1000000;
		$outBandwidth = $outBandwidth * 1000000;

		if (($inCode == 2) || ($outCode == 2))
		{
			my $output = "CRITICAL! $inOutput $outOutput | 'inbound bandwidth'=$inBandwidth, 'outbound bandwidth'=$outBandwidth";
			my $code = 2;
			exitScript ($output, $code);
		}

		if (($inCode == 1) || ($outCode == 1))
		{
			my $output = "WARNING! $inOutput $outOutput | 'inbound bandwidth'=$inBandwidth, 'outbound bandwidth'=$outBandwidth";
			$code = 1;
			exitScript ($output, $code);
		}

		else
		{
			my $output = "OK! $inOutput $outOutput | 'inbound bandwidth'=$inBandwidth, 'outbound bandwidth'=$outBandwidth";
			my $code = 0;
			exitScript ($output, $code);
		}
	}

	else
	{
		my $inBandwidthPerf = $inBandwidth * 1000000;
		my $outBandwidthPerf = $outBandwidth * 1000000;

		my $output = "OK! Inbound usage of $interface interface: $inBandwidth Mb/s. Outbound usage of $interface interace: $outBandwidth Mb/s. | 'inbound bandwidth'=$inBandwidthPerf, 'outbound bandwidth'=$outBandwidthPerf";
		my $code = 0;
		exitScript ($output, $code);
	}
}

sub countInterfaceBandwidth ()	# Counts interface bandwidth
{
	my $extendedOID = $_[0] . $_[1] . ".$_[2]";
	my $command = "/usr/bin/snmpget -v $_[3] -c $community $IP $extendedOID";
	my $result1 = `$command`;
	$result1 =~ m/^IF-MIB::if\w+Octets.$_[2]\s=\sCounter32:\s(\d+)$/;
	$result1 = $1;
	sleep 60;
	my $result2 = `$command`;
	$result2 =~ m/^IF-MIB::if\w+Octets.$_[2]\s=\sCounter32:\s(\d+)$/;
	$result2 = $1;
	my $octects = $result2 - $result1;
	my $bps = $octects / 60000000 * 8;
	$bps =~ m/(\d+\.\d{2}).*/;
	$bps = $1;
	return $bps;
}

sub exitScript ()	# Exits the script with an appropriate message and code
{
	print "$_[0]\n";
	exit $_[1];
}

sub getParameters ()	# Obtains script parameters and prints help if needed
{
	my $help = '';

	GetOptions ('help|?' => \$help,
		    'C=s' => \$community,
		    'H=s' => \$IP,
		    'I=s' => \$interface,
		    'warn:s' => \$warning,
		    'crit:s' => \$critical)

	or pod2usage (1);
	pod2usage (1) if $help;
	pod2usage (1) if (($community eq '') || ($IP eq '') || ($interface eq ''));
	pod2usage (1) if ($IP !~ m/^\d+\.\d+\.\d+\.\d+$/);
	if (($warning ne '') && ($critical ne ''))
	{
		pod2usage (1) if (($warning !~ m/^\d+$/) || ($critical !~ m/^\d+$/));
	}

=head1 SYNOPSIS

check_asa_interfaces.pl [options] (-help || -?)

=head1 OPTIONS

Mandatory:

-H	IP address of monitored Cisco ASA device

-C	SNMP community

-I	Interface name

Optional:

-warn	Warning threshold in Mb/s

-crit	Critical threshold in Mb/s

=cut
}
