package KeyNanny::Connector;

use strict;
use warnings;
use English;
use Moose;
use IO::Socket::UNIX qw( SOCK_STREAM );

extends 'Connector';

has 'socketfile' => (
    is => 'ro',
    required => 1,
    builder => '_init_socketfile'
);

has 'trim' => (
    is => 'ro',
    isa => 'Bool',
    default => 1
);


sub _init_socketfile {

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
    return $file;
}


sub get {

    my $self = shift;

    # In Config Mode, we have an empty path but use the
    # prefix to point to the right keynanny path
    # We will never have more than one segment
    my @path = $self->_build_path_with_prefix( shift );
    my $arg = shift @path;

    $self->log()->debug('Incoming keynanny request ' . $arg);

    my $socketfile = $self->socketfile();

    my $socket = IO::Socket::UNIX->new(
        Type => SOCK_STREAM,
        Peer => $socketfile
    ) or die "Cannot connect to server: $!. Stopped";

    if ( !defined $socket ) {
        die "Could not open socket $socketfile. Stopped";
    }

    print $socket 'get ' . $arg . "\r\n";

    local $/;
    my $result = <$socket>;

    $socket->close;

    if ($self->trim()) {
        $result =~ s{ \A \s* }{}xm;
        $result =~ s{ \s* \z }{}xm;
    }
    $self->log()->trace('keynanny result ' . $result );
    return $result;

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
