#!/bin/bash

echo "Creating package..."
version=$(head -n 1 VERSION)
perllibdir=$(perl -e 'use Config; use Data::Dumper; print $Config{installvendorlib}')
echo "Perl libs go to $perllibdir ..."
sed "s/VERSIONINFO/$version/" < packaging/Linux/keynanny.spec.in | sed "s'PERLLIBPATH'$perllibdir'" > packaging/Linux/keynanny.spec
mkdir keynanny-$version
tar cf - bin doc README.md lib examples | (cd keynanny-$version; tar xf -)
tar -czf $HOME/rpmbuild/SOURCES/keynanny-$version.tar.gz keynanny-$version
rm -rf keynanny-$version
rpmbuild -bb packaging/Linux/keynanny.spec

