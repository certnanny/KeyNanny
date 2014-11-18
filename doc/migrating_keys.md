# Migrating KeyNanny Keys

In certain situations, it may be necessary to migrate the data protected
by KeyNanny from one system to another. This process can be done easily
using openssl and the functions provided by KeyNanny.

*Important Disclaimer:* This can also be used to expose the contents of
KeyNanny. The overall security of your data depends on the processes and
restrictions your organization implements and follows. This process might
be adequate for a test environment, but not viable for use in production.
YMMV.

Basically, this process takes advantage of the re-keying feature in KeyNanny.
Re-keying is the process of creating a new encryption key for KeyNanny to 
use and have KeyNanny re-encrypt the existing protected data using the new
key. For the migration, a software key is generated on the target system. 
This key is then added to KeyNanny on the source system where the re-keying
takes place. The data files stored by KeyNanny can then be transfered to
the target system.

Note: Re-keying only works when the migration certificate has a "Not Before" 
date that is newer than all other encryption certificates used by KeyNanny.

# Preparing the Target System

Start by generating the software keys to be used for the migration.

    mkdir -p /var/lib/keynanny/crypto
    cd /var/lib/keynanny/crypto
    export PW=""
    openssl genrsa \
        -out kn-migration-key.pem \
        2048 2>/dev/null 
    chown root:keynanny kn-migration-key.pem
    chmod 0640 kn-migration-key.pem
    openssl req -509 -newkey rsa:2048 \
        -key kn-migration-key.pem -days 30 \
        -subj "/CN=Encryption Cert for Migration/O=KeyNanny/C=DE" \
        -out kn-migration-cert.pem

# Exporting the Source System

## Create backup and fetch key

    # create backup of storage directory
    cd /var/lib/keynanny
    tar czf storage.tar.gz storage

    # Check that the tokens are configured and usable
    keynannyd --check --config /etc/keynanny/openxpki.conf

    # fetch software key generated on TARGET system
    scp TARGET:/var/lib/keynanny/crypto/kn-migration-*.pem crypto/

## Edit Configuration File to Use Migration Key

    cp /etc/keynanny/openxpki.conf /etc/keynanny/openxpki.conf.mig

Add a token definition for the migration to the above configuration file.
It should look something like this:

    [keynanny-mig]
    certificate = $(crypto.base_dir)/kn-migration-cert.pem
    key = $(crypto.base_dir)/kn-migration-key.pem

To activate the above token entry, add it to the list of available
tokens (edit the 'token = ' to look like the following:

    token = keynanny-implicit, keynanny-mig

## Re-keying

At this point, we re-write the keys using the migration key. 

*IMPORTANT:* Your application must be stopped from now until when the
storage.tar.gz is recovered. The previous /etc/keynanny/openxpki.conf 
will not know how to read the re-keyed data files.

    # re-key
    keynannyd --check --config /etc/keynanny/openxpki.conf.mig --rekey
    # check the results
    keynannyd --check --config /etc/keynanny/openxpki.conf.mig

    # create new tarball of storage keys for TARGET system
    tar -czf storage-openxpki.tar.gz storage/openxpki

    # restore storage directory to previous configuration
    tar xzf storage.tar.gz

    # send migrated data to TARGET system
    scp storage-openxpki.tar.gz TARGET:/var/lib/keynanny/

# Importing Data on the Target System

## Edit Configuration File to Use Migration Key

Follow the instructions in the section above to add the migration token
to the /etc/keynanny/openxpki.conf.

## Importing the Data

    cd /var/lib/keynanny
    tar xzf storage-openxpki.tar.gz

    # check the results
    keynannyd --check --config /etc/keynanny/openxpki.conf
    
# Conclusion

Since the migration token was used on both systems, it makes sense to 
re-key once again on the TARGET system with a new key. Basically, it
consists of the following steps:

* Generate new key and cert
* Edit /etc/keynanny/openxpki.conf to include the new key and cert
* Run 'keynanny ... --rekey'
* Remove the migration key/cert from the /etc/keynanny/openxpki.conf

The actual commands for the re-keying can be taken from the steps above
as illustrated for the migration process.


