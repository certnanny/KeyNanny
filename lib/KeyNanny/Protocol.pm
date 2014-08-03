package KeyNanny::Protocol;
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

use IO::Socket::UNIX qw( SOCK_STREAM );
use Data::Dumper;
use Carp;

use base qw( KeyNanny );

sub new {
    my $class = shift;
    my $arg = shift;

    my $self = {};

    if ($arg->{SOCKET}) {
	$self->{SOCKET} = $arg->{SOCKET};
    }

    # note: SOCKET and SOCKETFILE are optional, if both are missing the class uses STDIN and STDOUT
    if ($arg->{SOCKETFILE}) {
	if ($self->{SOCKET}) {
	    confess "SOCKET and SOCKETFILE are mutually exclusive as initializing arguments to KeyNanny::Protocol";
	}

	if (! defined $arg->{SOCKETFILE}) {
	    confess("No socketfile specified");
	}

	$self->{SOCKETFILE} = $arg->{SOCKETFILE};
	
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
    }

    bless($self, $class);
    return $self;
}

# get a single command line from socket
sub receive {
    my $self = shift;
    my $arg = shift;
    
    my $fh = *STDIN;
    if (defined $self->{SOCKET}) {
	$fh = $self->{SOCKET};
    }
    
    my $data;
    if (! defined $arg->{LENGTH}) {
	$data = <$fh>;
	if (defined $data) {
	    $data =~ s/[\r\n]+$//;
	}
    } elsif ($arg->{LENGTH} == -1) {
	# read to EOF
	local $/;
	$data = <$fh>;
    } elsif ($arg->{LENGTH} =~ m{ \A \d+ \z}xms) {
	# read LENGTH bytes of data
	my $bytes_read = read $fh, $data, $arg->{LENGTH};
	if ($bytes_read != $arg->{LENGTH}) {
	    # TODO: what now?
	}
    } else {
	confess "Invalid LENGTH: $arg->{LENGTH}";
    }

    return $data;
}

sub send {
    my $self = shift;
    my $arg = shift;

    my $fh = *STDOUT;
    if (defined $self->{SOCKET}) {
	$fh = $self->{SOCKET};
    }

    if (! defined $arg->{DATA}) {
	return;
    }

    print $fh $arg->{DATA};

    if (! $arg->{BINARY}) {
	print $fh "\r\n";
    }
    return 1;
}

sub receive_command {
    my $self = shift;
    
    my $line = $self->receive();
    return if (! defined $line);

    # sanitize command: must only consist of alphanumeric characters
    my ($cmd, $args) = ($line =~ m{ \A (\w+) \s* (.*) }xms);

    # arguments are arbitrary words and must be sanitized saparately
    my $arg = [ split(/\s+/, $args) ];
    return {
	CMD => $cmd,
	ARG => $arg,
    };
}

sub send_command {
    my $self = shift;
    my $arg = shift;
    
    if (! defined $arg->{CMD}) {
	return;
    }
    
    my @arguments;
    if (defined $arg->{ARG}) {
	if (scalar $arg->{ARG} eq '') {
	    push @arguments, $arg->{ARG};
	} elsif (ref $arg->{ARG} eq 'ARRAY') {
	    push @arguments, @{$arg->{ARG}};
	}
    }
    
    return $self->send(
	{
	    DATA => join(' ', $arg->{CMD}, @arguments),
	});
}


sub send_response {
    my $self = shift;
    my $arg = shift;

    my $status = $arg->{STATUS};
    if ($status !~ m{ \A (?:OK|SERVER_ERROR|CLIENT_ERROR) \z }xms) {
	return;
    }
    my $response = $status;

    # message is optional
    if (defined $arg->{MESSAGE}) {
	$response .= ' ' . $arg->{MESSAGE};
    }
    
    $self->send(
	{
	    DATA   => $response,
	}) || return;
    
    
    if (defined $arg->{DATA}) {
	$self->send(
	    {
		DATA => $arg->{DATA},
		BINARY => 1,
	    }) || return;
    }

    return 1;
}


sub receive_response {
    my $self = shift;
    
    my $line = $self->receive();
    return if (! defined $line);

    # sanitize command: must only consist of alphanumeric characters
    my ($status, $message) = ($line =~ m{ \A (\w+) \s* (.*) }xms);
    
    my $result = {
	STATUS => 'COMMUNICATION_ERROR',
    };

    if (defined $status) {
	$result->{STATUS} = $status;
    }
    if (defined $message) {
	$result->{MESSAGE} = $message;
    }

    # if OK is returned followed by an integer the following n bytes are read and returned as well
    if ($status eq 'OK') {
	if ($message =~ m{ \A \d+ \z }xms) {
	    $result->{DATA} = $self->receive(
		{
		    LENGTH => $message,
		});
	}
    }
    
    return $result;
}

###########################################################################
# high level methods, may be used by KeyNanny clients
sub get {
    my $self       = shift;
    my $arg        = shift;

    $self->send_command(
	{
	    CMD => 'get',
	    ARG => [ $arg ],
	});

    return $self->receive_response();
}

sub set {
    my $self       = shift;
    my $key        = shift;
    my $value      = shift;

    $self->send_command(
	{
	    CMD => 'set',
	    ARG => [ $key, length($value) ],
	});

    my $rc = $self->send(
	{
	    DATA   => $value,
	    BINARY => 1,
	});

    return $self->receive_response();
}

sub list {
    my $self       = shift;

    $self->send_command(
	{
	    CMD => 'list',
	    ARG => [  ],
	});
    my $result = $self->receive_response();

    # convenience: return listed keys as arrayref
    if ($result->{STATUS} eq 'OK') {
	$result->{KEYS} = [ split(/\s+/, $result->{DATA}) ];
    }
    return $result;

}

1;
