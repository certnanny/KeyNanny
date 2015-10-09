use strict;
use warnings;
use Module::Build;
my $build = Module::Build->new(
    dist_abstract   => 'Credential protection and access control server',
    dist_author     => 'Martin Bartosch <mbartosch@cynops.de>',
    module_name => 'KeyNanny',
    license => 'apache',    # TODO: add 'gpl' as dual-license
    requires => {
        'Log::Log4perl'     => 0,
        'IO::Socket::UNIX'  => 0,
        'Moose'             => 0,
    },
    PL_files => {},
    share_dir => {
        dist => [ 'examples', 'util', ],
    }
);

$build->create_build_script;
