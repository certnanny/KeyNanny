#!/bin/sh

groupname=keynanny

solaris () {
  echo "OS $OS not supported, aborting..." 1&>2
  exit 1
}

aix () {
  echo "OS $OS not supported, aborting..." 1&>2
  exit 1
}

linux () {
  echo "Creating group $groupname if necessary..."
  getent group keynanny >/dev/null || groupadd -r $groupname
}


##### MAIN #####

OS=`uname -s`

if [ x"$OS" = "xSunOS" ]
then
  solaris
elif [ x"$OS" = "xLinux" ]
then
  linux
elif [ x"$OS" = "xAIX" ]
then
  aix
else
  echo "OS $OS not supported, aborting..." 1&>2
  exit 1
fi

