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
$autoanswer = $cfg->param('AutoAnswer');
$version = "1.1";
$aprsdst = $version =~ s/\.//r;
$aprsdst = sprintf "%03d", $aprsdst;
$aprsdst = "APB".$aprsdst;
$debug = 0;

$lat = substr($latitude,2,2).substr($latitude,5,5).substr($latitude,0,1);
$lon = substr($longitude,2,3).substr($longitude,6,5).substr($longitude,0,1);
$beaconstring = "${callsign}>$aprsdst,TCPIP*:=${lat}${overlay}${lon}${symbol}${comment}";

my $session = new Net::Telnet(Timeout => '30');
$session->errmode('return');
$session->Net::Telnet::open(Host => $server, Port => $port);
print $session "user $username pass $passcode vers APRSbouncer $version filter b/$callsign* g/$callsign*\n";
sleep 1;
my $lastbeaconin = time();
my $lastbeaconsent = time();
print $session "$beaconstring\n";
print "Last beacon on APRS-IS: ";
print strftime("%H:%M:%S ", localtime($lastbeaconin));
print "; last own beacon sent: ";
print strftime("%H:%M:%S", localtime($lastbeaconsent));
print "\n";
my $messagecount = 0;

while () {
   # Wait some time for possible beacon on the net
   if($line = $session->getline()) {
      # If we receive a beacon with own callsign on the net just 
      # reset the lastbeaconin timer
      if ($line =~ m/^$callsign>/) {
         # If we receive an ACK from another instance we do not need 
         # to answer but instead reset the message counter
         if ($line =~ m/ack\d+$/) {
            $messagecount = 0;
         } else {
            $lastbeaconin = time();
            print "Last beacon on APRS-IS: ";
            print strftime("%H:%M:%S ", localtime($lastbeaconin));
            print "; last own beacon sent: ";
            print strftime("%H:%M:%S", localtime($lastbeaconsent));
            print "\n";
         }
         if ($debug) {
            print strftime("%H:%M:%S ", localtime(time()));
            print $line;
         }
      }
      # Suppres status messages and comments on the net
      # but also handle own beacon as that is only executed if getline 
      # succeeded
      elsif ($line =~ /^#/) {
         if ($debug) {
            print strftime("%H:%M:%S ", localtime(time()));
            print $line;
         }
         # If no beacon was received on the net we will send a beacon
         if ((time() - $lastbeaconin) > ($interval * 60 + 60) && (time() - $lastbeaconsent) > ($interval * 60)) {
            print $session "$beaconstring\n";
            $lastbeaconsent = time();
            print "Last beacon on APRS-IS: ";
            print strftime("%H:%M:%S ", localtime($lastbeaconin));
            print "; last own beacon sent: ";
            print strftime("%H:%M:%S", localtime($lastbeaconsent));
            print "\n";
         }
      }
      elsif ($line =~ m/::$callsign\s*:/) {
         if ($debug) {
            print strftime("%H:%M:%S ", localtime(time()));
            print $line."\n";
         }
         $messagecount++;
         if ($messagecount > 1) {
            if ($line =~ m/^(\w*)>([a-zA-Z0-9,*-]+)::(\w+)\s*:(.*){(.*)$/) {
               my $from = $1;
               my $path = $2;
               my $to = $3;
               my $message = $4;
               my $ackno = $5;
               $from = sprintf "%-9s", $from;
               my $answer = "$callsign>$aprsdst,TCPIP*::$from:ack$ackno";
               print $session "$answer\n";
               my $ack = int(rand(100));
               my $autoanswer = "$callsign>$aprsdst,TCPIP*::$from:${autoanswer}\{$ack";
               print $session "$autoanswer\n";
               print strftime("%H:%M:%S ", localtime(time()));
               print "Sent auto answer to $from\n";
               $messagecount = 0;
            }
         }
      }
      else {
         if ($debug) {
            print strftime("%H:%M:%S ", localtime(time()));
            print $line;
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
   print $session "user $username pass $passcode vers APRSbouncer $version filter b/$callsign* g/$callsign*\n";
}
