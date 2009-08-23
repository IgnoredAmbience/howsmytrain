#!/usr/bin/perl
use Net::NationalRail::LiveDepartureBoards;

my $ldb = Net::NationalRail::LiveDepartureBoards->new();
my $hashref = $ldb->departures(rows => 10, crs => 'RUG');

print $hashref

