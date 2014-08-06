package KeyNanny::Connector;
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
use Moose;

use KeyNanny::Protocol;

extends 'Connector';

has 'trim' => (
    is => 'ro',
    isa => 'Bool',
    default => 1
);

has '_keynanny' => (
    is => 'rw',
    lazy => 1,
    init_arg => undef, # private attribute
    builder => '_init_keynanny',
);

sub _init_keynanny {
    my $self = shift;

    my $file = $self->LOCATION();

    if ( not defined $file ) {
        $self->log()->fatal( 'No socketfile defined. Stopped' );
        die "No socketfile defined. Stopped";
    }
    elsif ( not -e $file ) {
        $self->log()->fatal( "Socketfile $file does not exist. Stopped" );
        die "Socketfile $file does not exist. Stopped";
    }
    elsif ( not( -r $file && -w $file ) ) {
        $self->log()->fatal( "Socketfile $file is not accessible (permission problem?). Stopped" );
        die "Socketfile $file is not accessible (permission problem?). Stopped";
    }
    
    my $protocol = KeyNanny::Protocol->new( { SOCKETFILE => $file } );

    if (! defined $protocol) {
        die "Could not instantiate KeyNanny protocol. Stopped";
    }
    return $protocol;
}


sub get {
    my $self = shift;

    # In Config Mode, we have an empty path but use the
    # prefix to point to the right keynanny path
    # We will never have more than one segment
    my @path = $self->_build_path_with_prefix( shift );
    my $arg = shift @path;

    $self->log()->debug('Dispatching KeyNanny request for ' . $arg);

    my $result = $self->_keynanny()->get($arg);
    if (! defined $result) {
	die "Could not access KeyNanny daemon. Stopped";
    }

    my $data;
    if ($result->{STATUS} eq 'OK') {
	$data = $result->{DATA};
    } else {
	$self->log()->error('KeyNanny error: ' . $result->{MESSAGE} || 'n/a');
	die "Could not get data from KeyNanny. Stopped";
    }

    if ($self->trim()) {
        $data =~ s{ \A \s* }{}xm;
        $data =~ s{ \s* \z }{}xm;
    }
    return $data;
}

sub exists {
    my $self = shift;

    my $val;
    eval {
        $val = $self->get( shift );
    };
    return defined $val;
}

sub get_meta {
    return { TYPE => 'scalar' };
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 Name

KeyNanny::Connector

=head1 Description

Implementation of the connector API against a keynanny daemon.

=head1 Configuration

=head2 LOCATION

Path to the socketfile of the keynanny daemon, required, no default.

=head2 trim

Boolean, default true. If set removes left/right whitespace from the result.

=head1 Supported Methods

=head2 get

Takes the last element from path as query and asks keynanny.

=head2 get_meta

Always scalar.

=head2 exists

Runs get.

Implementation of the connector API against a keynanny daemon.

=head1 Supported Methods

=head2 get

Takes the last element from path as query and asks keynanny.

=head2 get_meta

Always scalar.

=head2 exists

Runs get.
