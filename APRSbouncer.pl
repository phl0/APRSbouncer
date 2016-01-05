#!/usr/bin/perl
use Config::Simple;
use Net::Telnet;

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
$string = "${callsign}>APB001,TCPIP*:=${lat}${overlay}${lon}${symbol}${comment}";

my $session = new Net::Telnet(Timeout => '60');
$session->errmode('return');
$session->Net::Telnet::open(Host => $server, Port => $port);
print $session "user $username pass $passcode vers APRSbouncer 0.1 filter b/$filtered_call*\n";
while () {
   $line = $session->getline();
   # Suppres status messages and comments on the net
   if ($line =~ /^[^#]/) {
      print $line;
   }
   $msg = $session->errmsg;
   recon() if ($msg);
}

sub recon {
   print "Error: $msg\n";
   $session->close();
   $session->Net::Telnet::open(Host => $server, Port => $port);
   print $session "user $username pass $passcode vers APRSbouncer 0.1 filter b/$callsign*\n";
}
