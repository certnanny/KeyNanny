#!/usr/bin/perl -w
#
# sopc.pl - Secure Oracle Password Change
#
# KeyNanny Edition :-)
#
# Change the password of an Oracle database user to a newly generated one
# 
# Author: Andreas Leibl
#         andreas@leibl.co.uk
#

use strict;

my $debug = 0;           # set to true to enable debug output
my $showpasswords = 0;   # DANGEROUS! For debugging only! Set to true to show password in clear text

my $dbuser = shift;
my $knsocket = shift;
my $knuser = shift;
my $oracleinstance = shift;

if ( (! $dbuser) || (! $knsocket) || (! $knuser) ) {
  print "Usage: $0 <database user name> </full/path/to/KeyNanny-Socket> <KeyNanny-User> [TNS instance name]\n";
  exit 1;
} else {
  print "Attempting to create new password for user $dbuser...\n";
}

my $rc;
my $currentpasswd;

if ( -r $knsocket ) {
  print "DEBUG: keynanny --socketfile $knsocket get $knuser\n" if ($debug);
  $currentpasswd = qx/keynanny --socketfile $knsocket get $knuser/;
  $rc = $?;
  chomp $currentpasswd;
  print "DEBUG: old passwd = $currentpasswd (rc = $rc)\n";
  if (($currentpasswd =~ m/^\s*$/) or ($rc != 0)) {
    print "ERROR: could not retrieve old password\n";
    exit 1;
  }
} else {
  print "ERROR: unable to find $knsocket, aborting...\n";
  exit 1;
}

my $newpasswd = "";
my $tries = 0;

while ($newpasswd eq "") {
  $tries++;

  # Create a long random string, base64 encoded
  my $randomstring = qx/openssl rand -base64 500/;
  $randomstring =~s/\n//g;
  
  # Now use a regex to find a 30 char substring that
  # adheres to all the rules below
  if ( $randomstring =~ m/([a-zA-Z])(?=.{0,28}\d)(?=.{0,28}[a-z])(?=.{0,28}[A-Z])(?=.{0,28}[+\/])(.{29})/ ) {
    $newpasswd = "$1$2";
    # now substitute the [+/] chars with [_]
    $newpasswd =~s/\+/_/g;
    $newpasswd =~s/\//_/g;
    print "DEBUG: new password = " . $newpasswd . "\n" if ($showpasswords);
  } else {
    print "DEBUG: no match!\n" if ($debug);
  }
}

print "Saving old password to ${knuser}SAVE...\n";
open(KN, "|keynanny --socketfile $knsocket set ${knuser}SAVE") or die "unable to save old password, aborting...";
print KN $currentpasswd;
close KN;
print "DEBUG: set ${knuser}SAVE rc=$?\n" if ($debug);

print "Saving new password to ${knuser}...\n";
open(KN, "|keynanny --socketfile $knsocket set ${knuser}") or die "unable to save old password, aborting...";
print KN $newpasswd;
close KN;
print "DEBUG: set ${knuser} rc=$?\n" if ($debug);

print "Changing password in the database...\n";
open (ORA, "|sqlplus /nolog") or die "unable to run sqlplus ...";
if ( $oracleinstance ) {
  print "DEBUG: connect $dbuser/$currentpasswd\@$oracleinstance\n" if ($debug && $showpasswords);
  print ORA "connect $dbuser/$currentpasswd\@$oracleinstance\n";
} else {
  print "DEBUG: connect $dbuser/\"$currentpasswd\"\n" if ($debug && $showpasswords);
  print ORA "connect $dbuser/\"$currentpasswd\"\n";
}
print "DEBUG: sqlplus rc=$?\n" if ($debug);
print ORA "WHENEVER SQLERROR EXIT FAILURE;\n";
print ORA "ALTER USER $dbuser IDENTIFIED BY \"$newpasswd\" REPLACE \"$currentpasswd\";\n";
print ORA "quit\n";
close ORA;
$rc = $?;
print "DEBUG: sqlplus rc=$rc\n" if ($debug);
if ($rc == -1) {
  print "failed to execute: $!\n";
} elsif ($rc & 127) {
  printf "child died with signal %d, %s coredump\n", ($rc & 127),  ($rc & 128) ? 'with' : 'without';
} else {
  $rc = $rc >> 8;
  printf "child exited with value %d\n", $rc;
  if ($rc eq 0) {
    print "Password change successful!\n";
    print "You may remove KeyNanny BLOB ${knuser}SAVE (optional).\n";
  } else {
    print "Password change FAILED!\n";
    print "You need to restore KeyNanny BLOB ${knuser} from ${knuser}SAVE.\n";
  }
}

__END__

=pod

=head1 NAME

sopc.pl - Secure Oracle Password Change

=head1 SYNOPSIS

sopc.pl <database user name> </full/path/to/KeyNanny-Socket> <KeyNanny-User> [TNS instance name]

=head1 DESCRIPTION

Protecting passwords is a difficult task. This script 
allows you to change the password for an Oracle database
user without ever seeing the new password.

This script generates new, strong passwords using openssl.
It does so by generating a long string and then looking for 
a suitable substring that conforms to the password rules 
(see below). This new password, however, is not revealed
but securely stored in KeyNanny instead. 

The current password is read from KeyNanny and copied to
a new KeyNanny BLOB. The new password is then stored in 
the old KeyNanny BLOB. Finally, sqlplus is used to change
the password in the Oracle database like in this example:

C<WHENEVER SQLERROR EXIT FAILURE;>
C<ALTER USER passwdtest IDENTIFIED BY "HALsb3yw1quqNrcUbbm_PG5iR__B91" REPLACE "Pav53JCEUfx48JlSHR8Wye3PuE0fV_";>
C<quit>

Note that you do not require DBA credentials to do this.

If the password change is unsuccessful an error message 
is displayed. The user can revert the KeyNanny changes 
by copying the new (backup) KeyNanny BLOB back to the old one.

=head1 PREREQUISITES

Requires KeyNanny, OpenSSL and sqlplus (Oracle).

=head1 OPTIONS

None.

=head1 Password rules

A password must conform to the following rules:

=over

=item * Password must start with a character [a-zA-Z]

=item * Passord must contain at least one of the list of 
        non-word and non-number chars

=item * Password must not contain any other characters then 
        word characters (alphanumeric plus "_") and 
        this char: "_"

=item * Password must contain at least one number

=item * Password must contain at least one lowercase char

=item * Password must contain at least one uppercase char

=item * Allow old password to be specified (migration into KeyNanny)

=back

=head1 ToDo

=over

=item * Make the password length a variable (currently fixed at 30)

=item * Make the password rules customizable

=item * Make the KeyNanny and Oracle changes atomic

=back

=head1 Author

Andreas Leibl <andreas@leibl.co.uk>


=cut


