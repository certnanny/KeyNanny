#!/bin/bash
# creates KeyNanny spec file and builds package.
# target location of KeyNanny library files (default: vendor perl path)
# can be overridden via PERLLIBDIR
#
# example:
# PERLLIBDIR=/opt/keynanny/lib/perl5 make_Linux_package.sh

echo "Creating package..."
version=$(head -n 1 VERSION)
[ -z "$PERLLIBDIR" ] && PERLLIBDIR=$(perl -e 'use Config; print $Config{installvendorlib}')
echo "Perl libs go to $PERLLIBDIR ..."
sed "s/VERSIONINFO/$version/" < packaging/Linux/keynanny.spec.in | sed "s'PERLLIBPATH'$PERLLIBDIR'" > packaging/Linux/keynanny.spec
mkdir keynanny-$version
tar cf - bin doc README.md lib examples | (cd keynanny-$version; tar xf -)
tar -czf $HOME/rpmbuild/SOURCES/keynanny-$version.tar.gz keynanny-$version
rm -rf keynanny-$version
rpmbuild -bb packaging/Linux/keynanny.spec

