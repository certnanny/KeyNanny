#!/usr/bin/env perl
#
# This is a *simple* cgi script to implement the keynanny password upload
# service.
#
# CONFIGURATION
#
# The configuation file is in JSON format and contains the following:
#
# {
#   "certfile": "PATH_TO_KEYNANNY_CERTFILE",
#   "spooldir": "spool"
# }
#
# Optionally, if the "keyfile" is also specified, the CGI script will
# verify that the data written to the ticket file is readable and the
# decrypted contents match the original value submitted by the user.
#
# The configuration file must be located in one of the following
# locations (first one found has precedence):
#
# * value of KEYNANNY_WEBUI_CFG env variable
# * webui.json in the current directory of the CGI script
# * /etc/keynanny/webui.json
#

use strict;
use warnings;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use JSON;
use File::Basename;
use Cwd;

sub pass_rules {
    my $pass = shift;

    return
           defined $pass
        && length($pass) >= 16
        &&    # minimum length is 16
        $pass =~ m{[A-Z]} &&    # at least one upper case char
        $pass =~ m{[a-z]} &&    # at least one lower case char
        $pass =~ m{[0-9]} &&    # at least one digit
        $pass =~ m{\W}          # at least one special char
        ;
}

sub get_config {
    my ( $cfgfile, $raw, $config, $fh );
    foreach my $f (
        $ENV{'KEYNANNY_WEBUI_CFG'},
        getcwd() . '/webui.json',
        '/etc/keynanny/webui.json'
        )
    {
        if ( defined $f && -f $f ) {
            $cfgfile = $f;
            last;
        }
    }
    if ( not $cfgfile ) {
        $@ = 'Configuration file (e.g.: webui.json) not found';
        return;
    }

    local $/;
    if ( not open( $fh, '<', $cfgfile ) ) {
        $@ = "Error reading config file: $!";
        return;
    }

    $config = from_json(<$fh>);
    return $config;
}

sub get_ticket_id {
    my $config = shift;
    if ( not -d $config->{spooldir} ) {
        $@ = "Server error: spooldir " . $config->{spooldir} . " not found";
        return;
    }

    my ( $ticket_id, $ticket_file );

    until ( $ticket_id && not -f $ticket_file ) {
        $ticket_id   = `openssl rand 48 | openssl sha1 | head -c 7`;
        $ticket_file = $config->{spooldir} . '/' . $ticket_id;
        chomp $ticket_id;

        #        print "<pre>DEBUG: generated ticket_id $ticket_id</pre>\n";
    }

    #    print "<pre>DEBUG: id=$ticket_id, file=$ticket_file</pre>\n";
    return ( $ticket_id, $ticket_file );
}

my $q = new CGI;
print $q->header;
print $q->start_html( -title => 'KeyNanny Password Upload Service' );
print $q->h1('KeyNanny Password Upload Service');

# Get password from upload, if submitted
my $password = $q->param('password');

if ( not $password ) {
    my $sample_password;
    until ( pass_rules($sample_password) ) {
        $sample_password = `openssl rand -base64 16`;
    }

    print $q->h2('Upload Form');

    print $q->p(
        'Please submit the password you wish to add to the KeyNanny ',
        'Password Upload Service. You may use your own password or use ',
        'the random generated password already suggested. A ticket ID will ',
        'be generated that you can refer to when informing our application ',
        'support team.'
    );

    print $q->start_form;

    print "Password: ";
    print $q->textfield(
        -name      => 'password',
        -value     => $sample_password,
        -size      => 30,
        -maxlength => 256,
    );

    print $q->submit(
        -name  => 'submit_form',
        -value => 'Upload',
    );
    print $q->end_form;
}
else {
    my $config = get_config() || die "Error reading config: $@";
    my ( $ticket_id, $ticket_file ) = get_ticket_id($config);
    my $certfile = $config->{certfile};
    my $keyfile  = $config->{keyfile};

    if ( not $ticket_id ) { die "Error generating ticket: $@"; }

    # Sanitize Password
    chomp($password);
    $password =~ s{[\r\n]}{}xmsg;    # be paranoid!

    my $out_fh;
    my $sslcmd
        = "openssl smime -encrypt -binary -aes256 -out $ticket_file -outform pem $certfile";
    open( $out_fh, '|-', $sslcmd )
        or die "Error running openssl for encrypting password: $!";

    print( $out_fh $password )
        or die "Error writing password to openssl command: $!";

    #warn "FAIL ENABLED!!!"; print $out_fh "\n";
    close($out_fh) or die "Error closing openssl filehandle: $!";

    my $encrypted_password;
    my $fh;
    if ( not open( $fh, '<', $ticket_file ) ) {
        die "Error reading encrypted password: $!";
    }

    my $encrypted_password = join( '', <$fh> );
    close $fh;

    my $success = 1;

    # VERIFY encryption
    if ( $config->{keyfile} ) {
        my $decrypted_password
            = `openssl smime -decrypt -in $ticket_file -inform PEM -inkey $keyfile`;

        $success = $password eq $decrypted_password;
        print
            "<pre>DEBUG: enc='$password', dec='$decrypted_password'</pre>\n";
    }

    print $q->h2( 'Upload ' . ( $success ? '' : 'Not ' ) . 'Successful' );

    print "<p>\n";
    print "Your request has ", ( $success ? '' : '<strong>not</strong> ' );
    print
        "been sucessfully uploaded to the KeyNanny Password Upload Service. ";
    print "</p><p>\n";
    print "The KeyNanny ticket ID is: $ticket_id\n";

    print $q->h2('Encrypted Password');

    print "<pre>\n";
    print $encrypted_password;
    print "</pre>\n";

}

$q->end_html;
