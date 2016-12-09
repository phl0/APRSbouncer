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
$version = "0.2";
$debug = 1;

$filtered_call = $callsign;
$filtered_call =~ s/-+\d{0,2}//;
$lat = substr($latitude,2,2).substr($latitude,5,5).substr($latitude,0,1);
$lon = substr($longitude,2,3).substr($longitude,6,5).substr($longitude,0,1);
$beaconstring = "${callsign}>APB001,TCPIP*:=${lat}${overlay}${lon}${symbol}${comment}";

my $session = new Net::Telnet(Timeout => '30');
$session->errmode('return');
$session->Net::Telnet::open(Host => $server, Port => $port);
print $session "user $username pass $passcode vers APRSbouncer $version filter b/$filtered_call*\n";
sleep 1;
my $lastinetbeacontime = time();
my $lastinetbeacontimesec, $lastinetbeacontimemin, $lastinetbeacontimehour, $lastinetbeacontimemday, $lastinetbeacontimemon, $lastinetbeacontimeyear, $lastinetbeacontimewday, $lastinetbeacontimeyday, $lastinetbeacontimeisdst;
my $lastownbeacontime = time();
my ($lastownbeacontimesec, $lastownbeacontimemin, $lastownbeacontimehour, $lastownbeacontimemday, $lastownbeacontimemon, $lastownbeacontimeyear, $lastownbeacontimewday, $lastownbeacontimeyday, $lastownbeacontimeisdst) = localtime($lastownbeacontime);
print $session "$beaconstring\n";
printf("\rLast beacon on APRS-IS: %02d:%02d:%02d; last own beacon sent: %02d:%02d:%02d", $lastinetbeacontimehour,$lastinetbeacontimemin,$lastinetbeacontimesec, $lastownbeacontimehour, $lastownbeacontimemin, $lastownbeacontimesec);

while () {
   # Wait some time for possible beacon on the net
   if($line = $session->getline()) {
      # Suppres status messages and comments on the net
      if ($line =~ /^[^#]/) {
         if ($debug) {
            print $line;
         }
      }
      if ($line =~ /^$callsign>/) {
         $lastinetbeacontime = time();
         ($lastinetbeacontimesec, $lastinetbeacontimemin, $lastinetbeacontimehour, $lastinetbeacontimemday, $lastinetbeacontimemon, $lastinetbeacontimeyear, $lastinetbeacontimewday, $lastinetbeacontimeyday, $lastinetbeacontimeisdst) = localtime($lastinetbeacontime);
         printf("\rLast beacon on APRS-IS: %02d:%02d:%02d; last own beacon sent: %02d:%02d:%02d", $lastinetbeacontimehour,$lastinetbeacontimemin,$lastinetbeacontimesec, $lastownbeacontimehour, $lastownbeacontimemin, $lastownbeacontimesec);
      }
   } else {
      # If no beacon was received on the net we will send a beacon
      if ((time() - $lastinetbeacontime) > ($interval * 60)) {
         print $session "$beaconstring\n";
         $lastinetbeacontime = time();
         ($lastinetbeacontimesec, $lastinetbeacontimemin, $lastinetbeacontimehour, $lastinetbeacontimemday, $lastinetbeacontimemon, $lastinetbeacontimeyear, $lastinetbeacontimewday, $lastinetbeacontimeyday, $lastinetbeacontimeisdst) = localtime($lastinetbeacontime);
         $lastownbeacontime = time();
         ($lastownbeacontimesec, $lastownbeacontimemin, $lastownbeacontimehour, $lastownbeacontimemday, $lastownbeacontimemon, $lastownbeacontimeyear, $lastownbeacontimewday, $lastownbeacontimeyday, $lastownbeacontimeisdst) = localtime($lastownbeacontime);
         printf("\rLast beacon on APRS-IS: %02d:%02d:%02d; last own beacon sent: %02d:%02d:%02d", $lastinetbeacontimehour,$lastinetbeacontimemin,$lastinetbeacontimesec, $lastownbeacontimehour, $lastownbeacontimemin, $lastownbeacontimesec);
      }
      #   $time = time();
      #$lastownbeacontime = time();
      #($nowsec, $nowmin, $nowhour, $nowmday, $nowmon, $nowyear, $nowwday, $nowyday, $nowisdst) = localtime();

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
   print $session "user $username pass $passcode vers APRSbouncer $version filter b/$filtered_call*\n";
}
