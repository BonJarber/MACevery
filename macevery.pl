#!/usr/bin/perl -w
#Jon Barber
#MAC Changer

use strict;
use Term::ReadKey;

my $os;
my $ip;
my $NIC;
my $MAC;
my $OUI;
my $newMAC;
my $currentMAC;
my $interval;
my %adapters;

sub OSCheck{
	if($^O eq "linux"){
	$os=0;
	}
	elsif($^O eq "MSWin32"){
		$os=1;
	}
	else{
		die "You must be running Windows or Linux\n";
	}
}

sub findAdapters{
	if($os==1){
		my @ip = `ipconfig /all`;
		my $adapter;
		for(@ip){
			if($_ =~ /adapter (.+):$/){
				$adapter = $1;
			}
			if($_ =~ /Physical Address[ .]+: (\w\w-\w\w-\w\w-\w\w-\w\w-\w\w)/){
				if($1 ne "00-00-00-00-00-00"){
					$adapters{$adapter} = $1;
				}
			}
		}
	}
	else{
		my @ip = `ifconfig`;
		for(@ip){
			if($_ =~ /^(\w+).*?HWaddr ([\w:]+)/){
				print "$1 found at $2\n";
				if($1 ne "00:00:00:00:00:00"){
					$adapters{$1} = $2;
				}
			}
		
		}
	}
}

sub pickAdapter {
	my @adapterlist=keys(%adapters);
	if(@adapterlist==0){
		die "No adapters found\n";
	}
	print "\n Which Adapter/MAC do you want to change?\n\n";
	for(my $i=1;$i<=@adapterlist;$i++){
		print "$i. $adapterlist[$i-1]/$adapters{$adapterlist[$i-1]}\n";
	}
	print "\nPick a number: ";
	chomp(my $choice = <>);
	$choice=$choice-1;
	if($choice<@adapterlist){
		$NIC=$adapterlist[$choice];
		$MAC=$adapters{$NIC};
	}
	else{
		print "Please choose a valid number\n";
		pickAdapter();
	}
}

sub options{
	print "\nNow set how often you want to randomize your MAC.\nEnter a number of minutes or 0 for just initial change\n : ";
	chomp(my $input = <>);
	$interval=$input*60;
	print "\nDo you want to use a specific OUI?(Y/N): ";
	chomp(my $choice = <>);
	if($choice eq "Y" or $choice eq("Yes") or $choice eq("YES") or $choice eq("y")){
		print "\n\nPlease enter the OUI in the format XX.XX.XX : ";
		chomp(my $input = <>);
		if($input=~ /(\w\w.\w\w.\w\w)/){
			$OUI=$1;
			$OUI=~s/[-\.]/:/g;
		}
		else{
			print "You didn't enter it correclty\n";
			options();
		}
	}
}

sub changeMAC{
	my $changeMAC=shift(@_);
	if($os==0){
		system("ip link set dev $NIC down");
		my $call = system("ip link set dev $NIC address $changeMAC");
		if($call==512){
			return 0;
		}
		system("ip link set dev $NIC up");
		return 1;
	}
	else{
		print "Changing of PC MAC address isn't currently supported\n";
	}
}

sub run{
	ReadMode 4;
	my $key;
	my $count=$interval;
	print "\n\n\n Script now running!\n";
	print "\nIt will keep running until you press a key\n";
	$currentMAC=generateMAC();
	my $change=changeMAC($currentMAC);
	while($change==0){
		$currentMAC=generateMAC();
		$change= changeMAC($currentMAC);
	}
	while(!defined($key = ReadKey(-1))){
		if($interval>0){
			if($count<$interval){
				$count++;
			}
			else{
				$currentMAC = generateMAC();
				my $change= changeMAC($currentMAC);
				while($change==0){
					$currentMAC=generateMAC();
					$change= changeMAC($currentMAC);
				}
				print "MAC changed to $currentMAC\n";
				$count=0;
			}
		}
		sleep 1;
	}
	ReadMode 0;
	print "All done, resetting your MAC\n";
	resetMAC();
}

sub generateMAC{
	$newMAC='';
	for(my $i =0;$i<11;$i++){
		if($i%2==0){
			my $byte=int(rand(255));
			my $hex=sprintf("%x",$byte);
			if($os==1){
				$hex=~ tr/a-z/A-Z/;
			}
			if($hex=~/^\w$/){
				$hex="0".$hex;
			}
			$newMAC=$newMAC.$hex;
		}
		else{
			if($os==0){
				$newMAC=$newMAC.":";
			}
			else{
				$newMAC=$newMAC."-";
			}
		}
	}
	if(defined($OUI)){
		$newMAC=~s/^(\w\w.\w\w.\w\w)/$OUI/;
	}
	return $newMAC;
}

sub resetMAC{
	changeMAC($MAC);
	if($os==0){
		print "Cleaning up for Linux";
		`sudo ifconfig $NIC down`;
		my $i=0;
		while($i<6){
			print " .";
			$i++;
			sleep 1;
		}
		`sudo ifconfig $NIC up`;
		print "\n\nGoodbye.\n";
	}
}
	
sub main{
	OSCheck();
	findAdapters();
	pickAdapter();
	options();
	run();
}

main();
