#!/usr/bin/perl -Tw
#
# Verify that all Asterisk native CSV records are stored in an AgileVoice CDR table
#
# Copyright (C) 2003-2005 Agileco LLC in association with Thralling Penguin LLC
#
#

use DBI;
use Text::CSV;

################### BEGIN OF CONFIGURATION ####################

# the name of the cdr table
$table_name = "ab_voip_cdr";
# the path to the Master.csv file
$csv_master = "/var/log/asterisk/cdr-csv/Master.csv";
# the name of the box the MySQL database is running on
$hostname = "localhost";
# the name of the database our tables are kept
$database = "agilevoice";
# username to connect to the database
$username = "agilevoice";
# password to connect to the database
$password = "";
# debugging mode?
$debug = 0;
################### END OF CONFIGURATION #######################

$dbh = DBI->connect("dbi:mysql:dbname=$database;host=$hostname", "$username", "$password");

sub get_id
{
	my ($table) = @_;

	$statement = "UPDATE ".$table."_id set id=LAST_INSERT_ID(id+1)";
	if ($debug) {
		print $statement, "\n";
	}
	$sth = $dbh->prepare($statement);
	$sth->execute;
	$id = $dbh->{mysql_insertid};
	$sth->finish;
	return $id;
}

sub verify
{
	my (@field) = @_;
	my $count = 0;

	$statement = "SELECT COUNT(*) FROM $table_name WHERE date_orig=UNIX_TIMESTAMP(".$dbh->quote($field[9]).") and channel=".$dbh->quote($field[5])." and dstchannel=".$dbh->quote($field[6]);
	if ($debug) {
		print $statement, "\n";
	}
	$sth = $dbh->prepare($statement);
	$sth->execute;
	my @result = $sth->fetchrow_array;
	$count = $result[0]; 
	$sth->finish;
	return $count;
}

sub insert_cdr
{
	my (@field) = @_;
	$id = get_id($table_name);
	$statement = "INSERT INTO $table_name (id,site_id,date_orig,clid,src,dst,dcontext,channel,dstchannel,lastapp,lastdata,duration,billsec,disposition,amaflags,accountcode) VALUES ($id,1,UNIX_TIMESTAMP(".$dbh->quote($field[9])."),".$dbh->quote($field[4]).",".$dbh->quote($field[1]).",".$dbh->quote($field[2]).",".$dbh->quote($field[3]).",".$dbh->quote($field[5]).",".$dbh->quote($field[6]).",".$dbh->quote($field[7]).",".$dbh->quote($field[8]).",".$dbh->quote($field[12]).",".$dbh->quote($field[13]).",".$dbh->quote($field[14]).",".$dbh->quote($field[15]).",".$dbh->quote($field[0]).")";
	if ($debug) {
		print $statement, "\n";
	}
	$dbh->do($statement);
}

my $csv = Text::CSV->new;
my $icount = 0;
my $ecount = 0;

open CSV, "<$csv_master" or die "Cannot open master csv file: $csv_master\n";
while ( ($line = <CSV>) ) {
	chomp $line;
	if ($csv->parse($line)) {
		my @field = $csv->fields;
		if (!verify(@field)) {
			insert_cdr(@field);
			$icount = $icount + 1;
		} else {
			#print "Record exists.\n";
			$ecount = $ecount + 1;
		}
	} else {
		my $err = $csv->error_input;
		print "parse() failed on argument: ", $err, "\n";
	}
}
close CSV;

print "There were ".$icount." records inserted.\n";
print "There were ".$ecount." records already in the database.\n";
exit 0;

