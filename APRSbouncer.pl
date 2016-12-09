#!/usr/bin/perl
use Config::Simple;
use Net::Telnet;
use POSIX qw( strftime );

# disable output buffering
$|=1;

$cfg = new Config::Simple('APRSbouncer.conf');

$callsign = $cfg->param('Callsign');
$latitude = $cfg->param('Latitude');
$longitude = $cfg->param('Longitude');
$comment = $cfg->param('Comment');
$overlay = $cfg->param('Overlay');
$symbol = $cfg->param('Symbol');
$interval = $cfg->param('Interval');
$server = $cfg->param('Server');
$port = $cfg->param('Port');
$username = $cfg->param('Username');
$passcode = $cfg->param('Passcode');
$version = "0.2";
$debug = 0;

$lat = substr($latitude,2,2).substr($latitude,5,5).substr($latitude,0,1);
$lon = substr($longitude,2,3).substr($longitude,6,5).substr($longitude,0,1);
$beaconstring = "${callsign}>APB001,TCPIP*:=${lat}${overlay}${lon}${symbol}${comment}";

my $session = new Net::Telnet(Timeout => '30');
$session->errmode('return');
$session->Net::Telnet::open(Host => $server, Port => $port);
print $session "user $username pass $passcode vers APRSbouncer $version filter b/$callsign*\n";
sleep 1;
my $lastbeaconin = time();
my $lastbeaconsent = time();
print $session "$beaconstring\n";
print "\rLast beacon on APRS-IS: ";
print strftime("%H:%M:%S ", localtime($lastbeaconin));
print "; last own beacon sent: ";
print strftime("%H:%M:%S", localtime($lastbeaconsent));

while () {
   # Wait some time for possible beacon on the net
   if($line = $session->getline()) {
      # If we receive a beacon with own callsign on the net just 
      # reset the lastbeaconin timer
      if ($line =~ /^$callsign>/) {
         $lastbeaconin = time();
         print "\rLast beacon on APRS-IS: ";
         print strftime("%H:%M:%S ", localtime($lastbeaconin));
         print "; last own beacon sent: ";
         print strftime("%H:%M:%S", localtime($lastbeaconsent));
      }
      # Suppres status messages and comments on the net
      # but also handle own beacon as that is only executed if getline 
      # succeeded
      if ($line =~ /^#/) {
         if ($debug) {
            print strftime("%H:%M:%S ", localtime(time()));
            print $line;
         }
         # If no beacon was received on the net we will send a beacon
         if ((time() - $lastbeaconin) > ($interval * 60)) {
            print $session "$beaconstring\n";
            $lastbeaconsent = time();
            print "\rLast beacon on APRS-IS: ";
            print strftime("%H:%M:%S ", localtime($lastbeaconin));
            print "; last own beacon sent: ";
            print strftime("%H:%M:%S", localtime($lastbeaconsent));
         }
      }
   }
   $msg = $session->errmsg();
   if ($msg) {
      sleep 10;
      recon();
   }
}

sub recon {
   print "\nError: $msg\n";
   $session->close();
   $session = new Net::Telnet(Timeout => '30');
   $session->errmode('return');
   $session->Net::Telnet::open(Host => $server, Port => $port);
   print $session "user $username pass $passcode vers APRSbouncer $version filter b/$callsign*\n";
}
