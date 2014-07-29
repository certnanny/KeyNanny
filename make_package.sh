#!/bin/sh
#
# make_package.sh
#
# Create CertNanny package
#

solaris () {
  echo "Solaris is not supported, yet ..." 1&>2
  exit 1
}

aix () {
  echo "AIX is not supported, yet ..." 1&>2
  exit 1
}

linux () {
  packaging/Linux/make_Linux_package.sh
}


##### MAIN #####

OS=`uname -s`

if [ x"$OS" = "xSunOS" ]
then
  echo "Packaging for $OS..."
  solaris
elif [ x"$OS" = "xLinux" ]
then
  echo "Packaging for $OS..."
  linux
elif [ x"$OS" = "xAIX" ]
then
  echo "Packaging for $OS..."
  aix
else
  echo "OS $OS not supported, aborting..." 1&>2
  exit 1
fi

