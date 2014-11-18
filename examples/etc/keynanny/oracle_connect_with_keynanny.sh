#!/bin/sh
#
# oracle_connect_with_keynanny.sh
#
# A simple shell script demonstrating the use of KeyNanny with Oracle sqlplus
#

# Parameters (change as needed)
socketfile=/var/lib/keynanny/run/app1.socket
keynannykey=app1pw01
oracleuser=app1
oracletnsname=XE

# Get Oracle password from KeyNanny
password=$(keynanny --socketfile $socketfile get $keynannykey)

# The simple way to connect would be to run
# sqplus $oracleuser/$password@oracletnsname
# but that would disclose the password to anyone
# on the system running ps -ef.
# So we need to do a little bit different:
# We run sqlplus without connection information
# and then write them to sqlplus' stdin. This
# way no information is leaked.
sqlplus /nolog << EOF
connect $oracleuser/$password@oracletnsname
select username, user_id from user_users;
EOF

