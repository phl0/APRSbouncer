#!/usr/bin/perl
use Config::Simple;
use Net::Telnet;

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

$filtered_call = $callsign;
$filtered_call =~ s/-+\d{0,2}//;
$lat = substr($latitude,2,2).substr($latitude,5,5).substr($latitude,0,1);
$lon = substr($longitude,2,3).substr($longitude,6,5).substr($longitude,0,1);
$beaconstring = "${callsign}>APB001,TCPIP*:=${lat}${overlay}${lon}${symbol}${comment}";

my $session = new Net::Telnet(Timeout => '5');
$session->errmode('return');
$session->Net::Telnet::open(Host => $server, Port => $port);
print $session "user $username pass $passcode vers APRSbouncer 0.1 filter b/$filtered_call*\n";
sleep 1;
my $time = time();
my $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst;
my $now = time();
my ($nowsec, $nowmin, $nowhour, $nowmday, $nowmon, $nowyear, $nowwday, $nowyday, $nowisdst) = localtime();
print $session "$beaconstring\n";
printf("\rLast beacon on APRS-IS: %02d:%02d:%02d; last own beacon sent: %02d:%02d:%02d", $hour,$min,$sec, $nowhour, $nowmin, $nowsec);

while () {
   # Wait some time for possible beacon on the net
   if($line = $session->getline()) {
      # Suppres status messages and comments on the net
      if ($line =~ /^[^#]/) {
         #print $line;
      }
      if ($line =~ /^$callsign>/) {
         #printf("Own beacon found. Resetting timer!\n");
         $time = time();
         ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($time);
         printf("\rLast beacon on APRS-IS: %02d:%02d:%02d; last own beacon sent: %02d:%02d:%02d", $hour,$min,$sec, $nowhour, $nowmin, $nowsec);
      }
   } else {
      # If no beacon was received on the net we will send a beacon
      $now = time();
      ($nowsec, $nowmin, $nowhour, $nowmday, $nowmon, $nowyear, $nowwday, $nowyday, $nowisdst) = localtime();
      if (($now - $time) > ($interval * 60)) {
         $time = time();
         printf("\rLast beacon on APRS-IS: %02d:%02d:%02d; last own beacon sent: %02d:%02d:%02d", $hour,$min,$sec, $nowhour, $nowmin, $nowsec);
         print $session "$beaconstring\n";
   }

   }
   $msg = $session->errmsg;
   recon() if ($msg != "read timed-out");
}

sub recon {
   print "Error: $msg\n";
   $session->close();
   $session->Net::Telnet::open(Host => $server, Port => $port);
   print $session "user $username pass $passcode vers APRSbouncer 0.1 filter b/$filtered_call*\n";
}
