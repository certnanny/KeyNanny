# DESCRIPTION

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

## Design

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

KeyNanny does \_not\_ honor the NotAfter date of certificates, nor does it consider CRLs, CA chains and trust management. 
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

## Integration and use cases

### Unmodified third party application, config files in temp file system

The standalone command line client is probably the most useful for unmodified applications which still require the configuration file in the application specific format, cleartext passwords included.

Here we assume that the application "demoapp" (running as Unix user demoapp and group nobody) requires two sensitive configuration items: 

- a configuration file /etc/demoapp/demoapp.conf containing the passwords for an LDAP account, a web service and the password for the authkey file (variables "ldap", "webservice", "authkeypassphrase")
- a binary file containing a cryptographic key /etc/demoapp/authkey.pem (variable "authkey")

The application requires that a lot of additional files in /etc/demoapp/, but none of those additional files contains sensitive information.

The integrator of the solution installs the demoapp application and prepares all the necessary files in /etc/demoapp, with the exception of /etc/demoapp/demoapp.conf and /etc/demoapp/client-key.pem.

The integrator then creates symlinks to a (not yet existing) directory:

    cd /etc/demoapp/
    ln -s /credentials/demoapp/demoapp.conf .
    ln -s /credentials/demoapp/authkey.pem .

This operation creates (dangling) symlinks in the application configuration directory.

Next, the integrator creates a file called /etc/demoapp/demoapp.conf.keynanny-template which contains exactly the required configuration.

In the template, appearances of the actual passwords are replaced with Template Toolkit variable references, e. g.:

    ...
    ldap_binduser = CN=Dummy App,O=KeyNanny,C=DE
    ldap_password = [% ldap %]
    ...
    webservice_url = https://soap.keynanny.example.com/service/...
    webservice_user = demoapp
    webservice_password = [% webservice %]
    webservice_clientcert = /etc/demoapp/client-cert.pem
    webservice_clientkey = /etc/demoapp/client-key.pem
...

Next the integrator creates the startup script for the KeyNanny instance. The keynanny distribution contains an example startscript app1.rc which provides a framework for rendering config files of an application to a tmp file system.

### Direct integration of KeyNanny in shell scripts

For Unix shell scripts use the supplied keynanny binary. It can query the KeyNanny credentia lprotection daemon and outputs the returned secret to STDOUT:

    FOOBAR_VALUE=`keynanny --socketfile /var/lib/keynanny/run/app1.socket get foobar`
    if [ $? != 0 ] ; then
        echo "An error occurred"
        exit 1
    fi

### Direct integration in **Perl** applications using the supplied KeyNanny::Protocol module

    use KeyNanny::Protocol;

    my $key = 'foobar';

    my $kn = KeyNanny::Protocol->new( 
      { SOCKETFILE => '/var/lib/keynanny/run/app1.socket } );

    if (! defined $kn) {
        die "Could not instantiate KeyNanny. Stopped";
    }
    my $result = $kn->get($key);
    if (! defined $result) {
        die "Error communicating with KeyNanny. Stopped";
    }
    if ($result->{STATUS} ne 'OK') {
        die "KeyNanny error: " . $result->{STATUS} . ": " 
          . $result->{MESSAGE} . "\n";
    }
    my $value = $result->{DATA};

    print "secret stored for $key is $value\n";

### Direct integation in C programs

TODO

### Direct integation in Java programs

TODO

# CONFIGURATION FILE

The configuration file uses the common ini file syntax. Section names are enclosed in square brackets, parameters within a section use the key = value syntax:

    [section]
    key = value

The following configuration directives may be used:

## \[keynanny\]

### **namespace** = NAMESPACE

> Optional. Defaults to the basename of the configuration file.
>
> Set the namespace keynanny will use. This influences the daemon process name and generated log entries and allows distinguishing multiple daemons on one system.

### **cache\_strategy** = preload|preload-relaxed|memcache

> Optional. Defaults to 'preload'.
>
> This configuration directive defines the behavior of keynanny when caching information.
>
> **preload**: On startup read all secrets, decrypt and cache them. Terminates with an error if a secret cannot be unlocked. This is the default.
>
> **preload-relaxed**: Like preload, but continues if a secret cannot be decrypted.
>
> **memcache**: Lazy loading of secrets (no preloading is done). Once a secret is requested, decrypt it and store the value using memcache. The values stored in memcache are encrypted with an ephemeral key only known to this particular keynanny instance. Data stored in memcache is integrity protected, attempted modification, replay or copying data to different values is not possible without keynanny noticing.

### **log** = console|syslog|log4perl

> Optional. Defaults to 'syslog'. Select logging mechanism.
>
> **syslog**: Log to syslog (facility local0). This is the default.
>
> **console**: Log to STDOUT (not useful when running as a daemon)
>
> **log4perl**: Log using Log::Log4Perl

### **log4perlconfig** = FILE

> Optional. Only used when using Log::Log4Perl.
>
> Specify the Log4Perl configuration file to use (only applicable for log = log4perl).

### **log4perlcategory** = CATEGORY

> Optional. Only used when using Log::Log4Perl.
>
> Specify the Log4Perl category to use.

## \[memcache\]

Optional section. Only used when using the cache\_strategy 'memcache'.

### **servers** = host, host, ...

> Comma separated list of memcache servers.

## \[crypto\]

### **openssl** = PATH\_TO\_OPENSSL

> Optional. Default: /usr/bin/openssl
>
> Specify the path to openssl binary. Please note that OpenSSL versions 1.0 and higher are slightly more efficient because with these versions it is possible to deduce the recipient information from the encrypted blobs in the storage directory.
>
> Previous versions will also work properly, but at the cost of some overhead: the keynannyd daemon will have to try all configured tokens to decrypt all available blobs.

### **token** = CRYPTO\_TOKEN1\_SECTION, CRYPTO\_TOKEN2\_SECTION, ...

> Comma separated list of CRYPTO\_TOKEN\_SECTIONs which contain definitions of encryption certificates.

## \[CRYPTO\_TOKEN\_SECTION\]

A crypto token is configured in a distinct section whose name can be chosen by the administrator. The tokens to use by keynanny are configured in section \[token\] via token = ...

At least one CRYPTO\_TOKEN\_SECTION is required for keynanny to work properly.

Within the section the following keys are used:

### **certificate** = PATH\_TO\_CERTIFICATE

> Mandatory.
>
> Path to an encryption certificate used for decrypting the CMS encoded files in the storage directory.
>
> Please note that you may use Shell Globs to match multiple certificates at once. In order to make this useful, the globbing syntax is extended by allowing brackets () to capture the strings that are matched by the specified wildcards. The matched strings can then be used as $1, $2, ... in the **key** definition.
>
> Due to the special syntax processing it is not possible to use () brackets in the filename itself!

### **key** = KEY\_DEFINITION

> Mandatory.
>
> Specification of the private key corresponding to **certificate**. This may be the path to a RSA file or an identifier referencing a key in an HSM.
>
> If the **certificate** uses the Glogging feature (and captures the matched characters with brackets ()) then the matched strings can be referenced via $1, $2,... in **key**

### **passphrase** = KEY\_PIN

> Optional.
>
> Passphrase of the software RSA key specified in **key**. 

### **engine** = ENGINE

> Optional.
>
> In order to use HSMs or Smartcards for protection of private keys it is necessary to specify the engine implementation to be used. For Thales nCipher HSMs you should set this value to "chil".
>
> Very likely you will also have to specify an "engine section" for OpenSSL that initializes the crypto device to allow private key operations. To do so, point **openssl\_engine\_config** to a section where the engine configuration is defined.

### **openssl\_engine\_config** = \[ENGINE\_CONFIG\_SECTION\]

> Administrator chosen name of the section that contains the OpenSSL engine configuration. See section \[ENGINE\_CONFIG\_SECTION\].

## \[ENGINE\_CONFIG\_SECTION\]

The name of this section is chosen by the administrator. It is the name that is referenced by **\[crypto\]** key openssl\_engine\_config.

This section contains arbitrary settings which will be literally propagated to the openssl configuration file and allows to pass options to (dynamic) engines.

The section may be referenced by any number of tokens.

## \[storage\]

### **dir** = DIR

> Mandatory.
>
> Base directory for reading/writing CMS blobs.
>
> Please note that it is possible to have multiple keynanny instances pointing to the same storage directory (but with different user, group or access control settings)

### **umask** = MODE

> Optional.
>
> Octal umask to use when writing data to storage directory.

## \[server\]

### **socket\_file** = PATH

> Mandatory.
>
> Path of the Unix Domain Socket to listen on.

### **socket\_mode** = MODE

> Optional.
>
> Octal mode that should be used to protect the keynanny socket file.

### **timeout** = TIMEOUT

> Optional. Default: 10s
>
> Timeout value for a server process. If a clients does not react within TIMOUT seconds the server closes the connection.

### **user** = USER

> Unix user the daemon will change to before listening for connections. Typically this should be the user of the consuming application.

### **group** = GROUP

> Unix group the daemon will change to before listening for connections. It is recommended to set this group to the same value (e. g. keynanny) for all keynanny instances on a host in order to allow the clients to write to the same run directory.

### **pid\_file** = PATH

> Location of the PID file written by the daemon.

### Additonal server configuration values

All other entries in the **\[server\]** section are literally passed to Net::Server::PreFork. From the module configuration:

         min_servers         \d+                     5
         min_spare_servers   \d+                     2
         max_spare_servers   \d+                     10
         max_servers         \d+                     50
         max_requests        \d+                     1000

## \[access\]

Access controls for clients connecting via the Unix Domain Socket.

### **read** = 0|1

> If set to 1 clients are allowed to read values from keynanny and obtain a list of the stored entries.

### **write** = 0|1

> If set to 1 clients are allowed to set values via keynanny.

# EXAMPLE CONFIGURATION

    [keynanny]
    cache_strategy = preload
    log = syslog

    [crypto]
    openssl = /usr/bin/openssl
    base_dir = /var/lib/keynanny/crypto

    # reference all tokens to use
    token = mytoken, alltokens, hsmtoken

    # an explicitly configured token, held in software
    [mytoken]
    certificate = $(crypto.base_dir)/my-cert.pem
    key = $(crypto.base_dir)/my-key.pem
    passphrase = 1234

    # this is an implicit configuration for many certificates
    [alltokens]
    # match *keynanny*-cert.pem in crypto dir, and remember the strings matched as $1 and $2
    certificate = $(crypto.base_dir)/(*)keynanny(*)-cert.pem
    # ... and use these variables to reference the corrsponding key
    key = $(crypto.base_dir)/$1keynanny$2-key.pem

    # and now we use an nCipher HSM to protect the private key
    [hsmtoken]
    certificate = $(crypto.base_dir)/hsm-cert.pem
    key = hsm-key
    engine = chil
    openssl_engine_config = chil_engine

    [chil_engine]
    engine_id = chil
    dynamic_path = /usr/lib64/engines/libchil.so
    SO_PATH = /opt/nfast/toolkits/hwcrhk/libnfhwcrhk.so
    THREAD_LOCKING = 1

    [storage]
    dir = /var/lib/keynanny/storage/$(keynanny.namespace)

    [server]
    user = wwwown
    group = keynanny
    socket_mode = 0700

    socket_file = /var/lib/keynanny/run/$(keynanny.namespace).socket
    pid_file = /var/lib/keynanny/run/$(keynanny.namespace).pid
    background = 1
    max_servers = 4

    [access]
    read = 1
    write = 0
