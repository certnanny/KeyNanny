# KeyNanny

KeyNanny implements a server infrastructure component, consisting of a server process and several client programs which handles credential protection and access control using standard operating system paradigms and existing cryptographic standards.

## Overview

KeyNanny addresses two common problems frequently encountered in server environments where duties (development, configuration management, deployment and operating) are separated between distinct user groups:

- how can system credentials required by the server applications be protected from developers, ordinary users, administrators or possibly intruders
- how can system credentials or other credentials be securely exchanged between members of different operator groups

In this context KeyNanny only addresses credentials that are used by programs, not by humans (e. g. the bind password of a technical LDAP account or a web server private key).

Often such credentials will simply be literally inserted into a configuration file so that the server process that needs to access a remote resource can readily use the required password - leaving the underlying system account open to unauthorized persons with read access to this configuration file:

- unprivileged users on the same system might have access if permissions are too permissive
- configurations files may be backed up centrally where backup admins have access to the credentials within
- configuration files are sometimes checked into source code repositories, exposing the passwords to unauthorized access

## Goals

KeyNanny cleverly combines standard features of Unix-like systems (such as file ownership and permissions, Unix interprocess communication and temp file systems) and cryptographic standards (CMS/PKCS#7) to build a credential management infrastructure that is easy to set up and understand for a Unix administrator.

The primary goal is to get rid of cleartext passwords and other sensitive information (e. g. cryptographic keys) in plain files stored on a server's disk or even a developer's workspace/repository.

In addition, KeyNanny also solves the problem of separating software deployment and server configuration from actual administration. With KeyNanny it is possible to manage the configuration files of a server system in a developer repository without storing any sensitive information in this repository.

An administrator can change the system credential without having to actually modify the configuration file.

The system implicitly solves the common problem how a password can be synchronized between two systems managed by different administrators. The password is encrypted by the person setting the password for the KeyNanny instance, and the result is a non-sensitive encrypted data structure which can only be accessed by the consumer of the password.


## A word of caution

KeyNanny is not perfect. It gives administrators a toolbox to better protect system credentials, but in the end a system that is booting without user interaction will always be able to automatically deduce all credentials needed for operation. No matter how convoluted the setup, a skilled attacker will be able to peel away layer after layer until finally the actual credential is obtained.

Given the architecture of today's Unix system and application programs it is between hard and impossible to hide all credentials from unauthorized access. To solve this problem entirely, hardware cryptography is needed, and applications need to migrate away from password based authentication to public key authentication (e. g. TLS Client authentication).

## Architecture
KeyNanny consists of the following components:

### One KeyNanny daemon per "access namespace"
For each "namespace" (typically a server process or web application, e. g. apache or a webmail client) a dedicated KeyNanny daemon process will be running, configured from a namespace specific configuration file.

This namespace specific KeyNanny daemon will typically run as the same Unix user (and/or group) as the server process it shall support.

On startup the KeyNanny daemon will create a Unix domain socket through which clients can connect to the KeyNanny process and query credentials. This socket file must be properly protected by Unix permissions (can be configured in the instance configuration file).

An arbitrary number of parallel KeyNanny processes can be started independently, all serving different applications.

### A persistent data store (aka directory with files in it)

This data store directory is used to persistently store the encrypted credentials for a namespace.
The contents of the data store are not sensitive, they may be world-readable (but they should be protected from unauthorized modification via proper Unix permissions).

Please note that different KeyNanny instances may share the same persistent data store. This may be useful in cases where distinct server processes are running (different Unix users), but it also allows a nifty use case: it is possible to configure one KeyNanny instance to serve the contents of a namespace read-only and have a different KeyNanny instance accessible for an administrator which has write-only access to the stored credentials. That way you could allow administrators to set applications passwords but not to read them.

### One or more asymmetric cryptographic keys and corresponding certificates

Each KeyNanny instance needs at least one asymmetric key pair (e. g. RSA 2048) and a corresponding X.509v3 Certificate for the public key. The certificate may be self-signed, but a PKI signed certificate is fine as well.
KeyNanny supports an arbitrary number of encryption keys/certificates. If more than one certificate is configured, KeyNanny uses the one with the highest NotBefore date for encryption of newly set credentials.
"Old" certificates and keys should be retained as long as there is still data encrypted for these old keys.

KeyNanny is capable of automatically detecting the correct decryption certificate, but this only works properly with OpenSSL version 1.0 and higher (KeyNanny falls back to trying all keys sequentially until one works and is less efficient with older OpenSSL versions).

More than one KeyNanny instance can use the same cryptographic keys. In fact, this is recommended: configure all KeyNanny instances to point to the same keys to avoid excessive key management.

KeyNanny does _not_ honor the NotAfter date of certificates, nor does it consider CRLs, CA chains and trust management. 
There is little point in doing so with this particular encryption application anyway, and it is not useful to enforce such a behaviour in this particular case. If you wish to replace your keys regularly, simply add a new key/cert to the configuration and KeyNanny will use the new one automatically (if its NotBefore is higher than those of the existing certificates).

KeyNanny supports Hardware Security Modules via OpenSSL engine. In fact this is the recommended operation mode and the only way to get rid of storing a credential (password or key) unencrypted on disk.

You can configure KeyNanny to use "software" keys (i. e. RSA PEM files, possibly encrypted), but then you will have to either leave the key unencrypted or... write the password in KeyNanny's configuration file. Doh!

BTW, if you have stupid policies that prohibit this (which is impossible) you can sneak around this and Rot13 or Base64 your RSA password and store this obfuscated value in the KeyNanny configuration: KeyNanny is capable of evaluating Perl code in its configuration files - go figure...

### Client programs talking to KeyNanny

While the task of the KeyNanny daemon is to manage decryption of credentials and limit access to these credentials, you will need clients connecting to KeyNanny to actually do something useful with it.

The KeyNanny project comes with 
- a standalone command line client
- a Perl Connector implementation (https://github.com/mrscotty/connector)
- a Perl class that allows other Perl programs to talk to KeyNanny.

In the future there may also be libraries for C, Python, Ruby and other commonly used languages.

The command line client can either obtain the raw value of a credential or it can be used to render a configuration file from a template, replacing contained variables with the values obtained from KeyNanny.


### System runtime infrastructure

KeyNanny includes an init script that starts or stops all configured KeyNanny instances of a system at once. It is also possible to start/stop a single KeyNanny instance, though.

The init script checks if a standard shell rc script exists for any KeyNanny instance it tries to start/stop and execute the shell script (with the argument start/stop) when launching/stopping the KeyNanny daemon.

With this mechanism the system administrator can adapt how KeyNanny is integrated with the system. It allows to prepare temporary file systems, render configuration files replacing KeyNanny protected variables and or kick the application itself to reload its configuration file.


## Use cases

### Unmodified third party application, config files in temp file system

The standalone command line client is probably the most useful for unmodified applications which still require the configuration file in the application specific format, cleartext passwords included.

Here we assume that the application "demoapp" (running as Unix user demoapp and group nobody) requires two sensitive configuration items: 
- a configuration file /etc/demoapp/demoapp.conf containing the passwords for an LDAP account, a web service and the password for the authkey file (variables "ldap", "webservice", "authkeypassphrase")
- a binary file containing a cryptographic key /etc/demoapp/authkey.pem (variable "authkey")

The application requires that a lot of additional files in /etc/demoapp/, but none of those additional files contains sensitive information.

The integrator of the solution installs the demoapp application and prepares all the necessary files in /etc/demoapp, with the exception of /etc/demoapp/demoapp.conf and /etc/demoapp/client-key.pem.

The integrator then creates symlinks to a (not yet existing) directory:

```
cd /etc/demoapp/
ln -s /credentials/demoapp/demoapp.conf .
ln -s /credentials/demoapp/authkey.pem .
```

This operation creates (dangling) symlinks in the application configuration directory.

Next, the integrator creates a file called /etc/demoapp/demoapp.conf.template which contains exactly the required configuration. 

In the template, appearances of the actual passwords are replaced with Template Toolkit variable references, e. g.:

```
...
ldap_binduser = CN=Dummy App,O=KeyNanny,C=DE
ldap_password = [% ldap %]
...
webservice_url = https://soap.keynanny.example.com/service/...
webservice_user = demoapp
webservice_password = [% webservice %]
webservice_clientcert = /etc/demoapp/client-cert.pem
webservice_clientcert = /etc/demoapp/client-key.pem
...
```

Next the integrator creates the startup script for the KeyNanny instance (this is only an example to illustrate the point, actual scripts will have to use more error checking):

```
cat <<EOF >/etc/keynanny/demoapp.rc
#!/bin/bash
case "$1" in
    start)
        umount /credentials/demoapp
	mount -t tmpfs -o size=128000 /credentials/demoapp/
	# make sure all files are created with permissions r-------- and directories r-x------
	umask 0277

	chown demoapp:root /credentials/demoapp/
	# not necessary due to umask: chmod 500 /credentials/demoapp
	for file in /etc/demoapp/*.template ; do
	    outfile=`basename ${file%%.template}`
	    # render config file from template to temp file system
	    keynanny --socketfile /var/lib/keynanny/demoapp.socket template $file >/credentials/demoapp/$outfile
	    chown demoapp:root /credentials/demoapp/$outfile
	    # chmod 400 /credentials/demoapp/$outfile
	done
	umask 
	# and place the key file in this directory as well
	keynanny --socketfile /var/lib/keynanny/demoapp.socket get authkey >/credentials/demoapp/client-key.pem
	chown demoapp:root /credentials/demoapp/client-key.pem
	# chmod 400 /credentials/demoapp/client-key.pem
        ;;
    stop)
	umount /credentials/demoapp
	;;
esac
EOF
```

We are almost done. The KeyNanny rc script will create the temp file system and create the sensitive files in it. After this script terminates, the demoapp application should start without a problem.

Possible improvements: if demoapp slurps in its configuration files after successful startup, it is even possible to unmount /credentials/demoapp. The rc script could fork of a watchguard to wait for successful startup and perform the unmount operation.


