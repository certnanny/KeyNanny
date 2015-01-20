package KeyNanny;
#
# KeyNanny provides a framework to protect sensitive data on a Unix host.
#
# Copyright (c) 2014 The CertNanny Project
#
# Licensed under the Apache License, Version 2.0 and the GNU General Public License, Version 2.0.
# See the LICENSE file for details.
#

use strict;
use warnings;
use English;

use Carp;
use Data::Dumper;
use Log::Log4perl qw( :easy );
use KeyNanny::Protocol;

sub new {
    my $class = shift;
    my $arg = shift;

    my $logger;

    if (defined $arg->{LOGGER}) {
	$logger = $arg->{LOGGER};
    } else {
	if (defined $arg->{LOG4PERL_PACKAGENAME}) {
	    $logger = Log::Log4perl->get_logger($arg->{LOG4PERL_PACKAGENAME});
	} else {
	    Log::Log4perl->easy_init($ERROR);
	    $logger = get_logger();
	}
    }

    my $self = {
	LOG => $logger,
    };
    bless($self, $class);

    $self->{PROTOCOL} = KeyNanny::Protocol->new($arg);

    if (! $self->{PROTOCOL}) {
	$self->{LOG}->error("KeyNanny::new(): Could not instantiate KeyNanny protocol");
	confess("Could not instantiate KeyNanny protocol");
    }

    return $self;
}

sub ping {
    my $self       = shift;

    # reopen socket
    $self->{PROTOCOL}->init_socket();

    $self->{PROTOCOL}->send_command(
	{
	    CMD => 'ping',
	    ARG => [  ],
	});
    return $self->{PROTOCOL}->receive_response();
}

# high level methods, may be used by KeyNanny clients
sub get {
    my $self       = shift;
    my $arg        = shift;

    # reopen socket
    $self->{PROTOCOL}->init_socket();
    $self->{PROTOCOL}->send_command(
	{
	    CMD => 'get',
	    ARG => [ $arg ],
	});

    return $self->{PROTOCOL}->receive_response();
}

sub set {
    my $self       = shift;
    my $key        = shift;
    my $value      = shift;

    # reopen socket
    $self->{PROTOCOL}->init_socket();

    $self->{PROTOCOL}->send_command(
	{
	    CMD => 'set',
	    ARG => [ $key, length($value) ],
	});

    my $rc = $self->{PROTOCOL}->send(
	{
	    DATA   => $value,
	    BINARY => 1,
	});

    return $self->{PROTOCOL}->receive_response();
}

sub link {
    my $self       = shift;
    my $to         = shift;
    my $from       = shift;

    # reopen socket
    $self->{PROTOCOL}->init_socket();
    $self->{PROTOCOL}->send_command(
	{
	    CMD => 'link',
	    ARG => [ $to, $from ],
	});
    my $result = $self->{PROTOCOL}->receive_response();
    #print Dumper($result);
    return $result;
}

sub list {
    my $self       = shift;

    # reopen socket
    $self->{PROTOCOL}->init_socket();

    $self->{PROTOCOL}->send_command(
	{
	    CMD => 'list',
	    ARG => [  ],
	});
    my $result = $self->{PROTOCOL}->receive_response();

    # convenience: return listed keys as arrayref
    if ($result->{STATUS} eq 'OK') {
	$result->{KEYS} = [ split(/\s+/, $result->{DATA}) ];
    } else {
	$self->{LOG}->error("KeyNanny::list(): error getting list of keys: $result->{STATUS}:$result->{MESSAGE}");
    }
    return $result;
}

1;
