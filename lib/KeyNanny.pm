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

use Carp;
use KeyNanny::Protocol;
use IO::Socket::UNIX qw( SOCK_STREAM );

use Data::Dumper;

sub new {
    my $class = shift;
    my $arg = shift;

    my $self = {};

    if (! defined $arg->{socketfile}) {
	confess("No socketfile specified");
    }

    $self->{SOCKETFILE} = $arg->{socketfile};

    if (! -r $self->{SOCKETFILE} ) {
	confess("Socketfile $self->{SOCKETFILE} is not readable");
    }
    if (! -w $self->{SOCKETFILE} ) {
	confess("Socketfile $self->{SOCKETFILE} is not writable");
    }

    $self->{SOCKET} = IO::Socket::UNIX->new(
        Type => SOCK_STREAM,
        Peer => $self->{SOCKETFILE},
    ) or confess "Cannot connect to server: $!";

    if ( !defined $self->{SOCKET} ) {
        confess "Could not open socket $self->{SOCKETFILE}";
    }

    $self->{PROTOCOL} = KeyNanny::Protocol->new(
	{
	    SOCKET => $self->{SOCKET},
	});

    if (! $self->{PROTOCOL}) {
	confess "Could not instantiate protocol";
    }

    bless($self, $class);
    return $self;
}

sub get_var {
    my $self       = shift;
    my $arg        = shift;

    $self->{PROTOCOL}->send_command(
	{
	    CMD => 'get',
	    ARG => [ $arg ],
	});

    return $self->{PROTOCOL}->receive_response();
}

sub set_var {
    my $self       = shift;
    my $key        = shift;
    my $value      = shift;

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

sub list_vars {
    my $self       = shift;

    $self->{PROTOCOL}->send_command(
	{
	    CMD => 'list',
	    ARG => [  ],
	});
    my $result = $self->{PROTOCOL}->receive_response();

    # convenience: return listed keys as arrayref
    if ($result->{STATUS} eq 'OK') {
	$result->{KEYS} = [ split(/\s+/, $result->{DATA}) ];
    }
    return $result;
}


1;
