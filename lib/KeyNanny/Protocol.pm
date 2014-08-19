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
use Log::Log4perl qw( :easy );

use Data::Dumper;
use English;
use Carp;

use base qw( KeyNanny );

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

    if ($arg->{SOCKET}) {
	$self->{SOCKET} = $arg->{SOCKET};
    }

    # note: SOCKET and SOCKETFILE are optional, if both are missing the class uses STDIN and STDOUT
    if ($arg->{SOCKETFILE}) {
	if ($self->{SOCKET}) {
	    $self->{LOG}->error("KeyNanny::Protocol::new(): SOCKET and SOCKETFILE are mutually exclusive as initializing arguments to KeyNanny::Protocol");
	    confess "SOCKET and SOCKETFILE are mutually exclusive as initializing arguments to KeyNanny::Protocol";
	}

	if (! defined $arg->{SOCKETFILE}) {
	    $self->{LOG}->error("KeyNanny::Protocol::new(): No socketfile specified");
	    confess("No socketfile specified");
	}

	$self->{SOCKETFILE} = $arg->{SOCKETFILE};
	$self->_init_socket();
    }

    return $self;
}

sub _init_socket {
    my $self = shift;

    return unless defined $self->{SOCKETFILE};

    if (! -r $self->{SOCKETFILE} ) {
	$self->{LOG}->error("KeyNanny::Protocol::new(): Socketfile $self->{SOCKETFILE} is not readable");
	confess("Socketfile $self->{SOCKETFILE} is not readable");
    }
    if (! -w $self->{SOCKETFILE} ) {
	$self->{LOG}->error("KeyNanny::Protocol::new(): Socketfile $self->{SOCKETFILE} is not writable");
	confess("Socketfile $self->{SOCKETFILE} is not writable");
    }

    if (defined $self->{SOCKET}) {
	$self->{SOCKET}->close();
	$self->{SOCKET} = undef;
    }

    $self->{SOCKET} = IO::Socket::UNIX->new(
	Type => SOCK_STREAM,
	Peer => $self->{SOCKETFILE},
	);
    
    if (! $self->{SOCKET}) {
	my $err = $!;
	$self->{LOG}->error("KeyNanny::Protocol::new(): Cannot connect to server via $self->{SOCKETFILE}: $err");
	confess "Cannot connect to server via $self->{SOCKETFILE}: $err";
    }
    return 1;
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
	} else {
	    $self->{LOG}->error("KeyNanny::Protocol::receive(): no data line read");
	}
    } elsif ($arg->{LENGTH} == -1) {
	# read to EOF
	local $/;
	$data = <$fh>;
	if (! defined $data) {
	    $self->{LOG}->error("KeyNanny::Protocol::receive(): no data read");
	}
    } elsif ($arg->{LENGTH} =~ m{ \A \d+ \z}xms) {
	# read LENGTH bytes of data
	my $bytes_read = read $fh, $data, $arg->{LENGTH};
	if ($bytes_read != $arg->{LENGTH}) {
	    $self->{LOG}->error("KeyNanny::Protocol::receive() only read $bytes_read bytes (expected: $arg->{LENGTH})");
	    # TODO: what now?
	}
    } else {
	$self->{LOG}->error("KeyNanny::Protocol::receive(): invalid LENGTH specification: $arg->{LENGTH}");
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
	$self->{LOG}->info("KeyNanny::Protocol::send(): no data to send");
	return 1;
    }

    eval {
	print $fh $arg->{DATA};
    };
    if ($EVAL_ERROR) {
	$self->{LOG}->error("KeyNanny::Protocol::send(): EVAL_ERROR: $EVAL_ERROR");
	print STDERR "EVAL_ERROR: $EVAL_ERROR\n";
    }

    if (! $arg->{BINARY}) {
	print $fh "\r\n";
    }
    return 1;
}

sub receive_command {
    my $self = shift;
    
    my $line = $self->receive();
    if (! defined $line) {
	$self->{LOG}->error("KeyNanny::Protocol::receive_command(): no command received");
	return;
    }

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
	$self->{LOG}->error("KeyNanny::Protocol::send_command(): no command specified");
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
	$self->{LOG}->error("KeyNanny::Protocol::send_response(): invalid status received: $status");
	return;
    }
    my $response = $status;

    # message is optional
    if (defined $arg->{MESSAGE}) {
	$response .= ' ' . $arg->{MESSAGE};
    }

    if (! $self->send(
	      {
		  DATA   => $response,
	      })) {
	$self->{LOG}->error("KeyNanny::Protocol::send_response(): could not send response");
	return;
    }
    
    
    if (defined $arg->{DATA}) {
	if (! $self->send(
		  {
		DATA => $arg->{DATA},
		BINARY => 1,
		  })) {
	    $self->{LOG}->error("KeyNanny::Protocol::send_response(): could not send data");
	    return;
	}
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
	} else {
	    $self->{LOG}->error("KeyNanny::Protocol::receive_response(): invalid message: $message");
	}
    }
    
    return $result;
}

###########################################################################
# high level methods, may be used by KeyNanny clients
sub get {
    my $self       = shift;
    my $arg        = shift;

    # reopen socket
    $self->_init_socket();

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

    # reopen socket
    $self->_init_socket();

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

    # reopen socket
    $self->_init_socket();

    $self->send_command(
	{
	    CMD => 'list',
	    ARG => [  ],
	});
    my $result = $self->receive_response();

    # convenience: return listed keys as arrayref
    if ($result->{STATUS} eq 'OK') {
	$result->{KEYS} = [ split(/\s+/, $result->{DATA}) ];
    } else {
	$self->{LOG}->error("KeyNanny::Protocol::list(): error getting list of keys: $result->{STATUS}:$result->{MESSAGE}");
    }
    return $result;

}

1;
