# NOTE: This is a MOCK package for KeyNanny!!!
#
package KeyNanny;
use Moose;

has 'socketfile' => (is => 'ro', required => 0);

sub get_var {
    my $self = shift;
    my $arg = shift;

    # We don't actually care what the arg is. We just reverse and return
    return join('', reverse split(//, $arg));
}

no Moose;
1;
