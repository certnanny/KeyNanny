package KeyNanny;

use Carp;
use IO::Socket::UNIX qw( SOCK_STREAM );

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

    bless($self, $class);
    return $self;
}

sub get_var {
    my $self       = shift;
    my $arg        = shift;

    my $socketfile = $self->{SOCKETFILE};

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

sub set_var {
    my $self       = shift;
    my $arg        = shift;
    my $value      = shift;

    my $socketfile = $self->{SOCKETFILE};

    my $socket = IO::Socket::UNIX->new(
        Type => SOCK_STREAM,
        Peer => $socketfile
    ) or die "Cannot connect to server: $!. Stopped";

    if ( !defined $socket ) {
        die "Could not open socket $socketfile. Stopped";
    }

    print $socket 'set ' . $arg . "\r\n";
    print $socket $value;
    $socket->close;

    return $result;
}

sub list_vars {
    my $self       = shift;
    my $arg        = shift;

    my $socketfile = $self->{SOCKETFILE};

    my $socket = IO::Socket::UNIX->new(
        Type => SOCK_STREAM,
        Peer => $socketfile
    ) or die "Cannot connect to server: $!. Stopped";

    if ( !defined $socket ) {
        die "Could not open socket $socketfile. Stopped";
    }

    print $socket "list\r\n";

    my @result;
    while (my $line = <$socket>) {
	chomp $line;
	$line =~ s/\s*$//g;
	push @result, $line;
    }
    $socket->close;

    return @result;
}

1;
