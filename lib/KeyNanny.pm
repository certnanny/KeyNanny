package KeyNanny;
use Moose;

use IO::Socket::UNIX qw( SOCK_STREAM );

has 'socketfile' => ( is => 'ro', required => 1 );

sub BUILD {
    my $self = shift;

    my $file = $self->socketfile();

    if ( not defined $file ) {
        die "No socketfile defined. Stopped";
    }
    elsif ( not -e $file ) {
        die "Socketfile $file does not exist. Stopped";
    }
    elsif ( not( -r $file && -w $file ) ) {
        die
            "Socketfile $file is not accessible (permission problem?). Stopped";
    }
    return;
}

sub get_var {
    my $self       = shift;
    my $arg        = shift;
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

    return $result;
}

no Moose;
1;
