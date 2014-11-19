# QUICKSTART

This quickstart guide will explain the steps necessary to
get KeyNanny running with the example files provided.

## Part 1: Setting up the infrastructure

This part requires root authority.

### UNIX/Linux setup

- Installing the KeyNanny RPM will create a group called keynanny.
- If your application user is not in group "keynanny", add it.
- Log out and back in again for this change to take effect.
- Verify KeyNanny is installed

        # rpm -q keynanny
        keynanny-1.5.0-1


### Keys and certificates

- Go to the directory that will store the keys and certificates

        # cd /var/lib/keynanny/crypto/

- Create RSA keys without password protection

        # openssl genrsa -out kn01-key.pem 2048
        # openssl genrsa -out kn02-key.pem 2048

- create a config file

        # cat selfsign.cfg
        [ req ]
        distinguished_name     = req_distinguished_name
        prompt                 = no
        
        [ req_distinguished_name ]
        C                      = SE
        ST                     = Taka Tuka
        L                      = KeyNanny Test Centre
        O                      = KeyNanny
        OU                     = KeyNanny QA
        CN                     = KeyNanny Test Hero
        emailAddress           = keynanny@example.com

- Create corresponding self-signed certificates (valid for 10 years)

        # openssl req -new -x509 -config selfsign.cfg -key kn01-key.pem -out kn01-cert.pem -days 3653
        # openssl req -new -x509 -config selfsign.cfg -key kn02-key.pem -out kn02-cert.pem -days 3653

- Optional: Check the certificates

        # openssl x509 -in kn01-cert.pem -text
        # openssl x509 -in kn02-cert.pem -text

- IMPORTANT: Fix the permissions of the key files!
  By default, all the file you've created are world-readable.
  That is OK for certificates (not sensitive), but NOT for 
  keys (very sensitive)!

        # ls -l
        total 20
        -rw-r--r-- 1 root root 1387 Nov 18 19:34 kn01-cert.pem
        -rw-r--r-- 1 root root 1679 Nov 18 19:32 kn01-key.pem
        -rw-r--r-- 1 root root 1387 Nov 18 19:34 kn02-cert.pem
        -rw-r--r-- 1 root root 1675 Nov 18 19:33 kn02-key.pem
        -rw-r--r-- 1 root root  383 Nov 18 19:33 selfsign.cfg
        # chmod 640 kn*-key.pem
        # ls -l
        total 20
        -rw-r--r-- 1 root root 1387 Nov 18 19:34 kn01-cert.pem
        -rw-r----- 1 root root 1679 Nov 18 19:32 kn01-key.pem
        -rw-r--r-- 1 root root 1387 Nov 18 19:34 kn02-cert.pem
        -rw-r----- 1 root root 1675 Nov 18 19:33 kn02-key.pem
        -rw-r--r-- 1 root root  383 Nov 18 19:33 selfsign.cfg
        #

- Create the application directories
- Do not forget to assign the correct user/group/permissions

        # mkdir /var/lib/keynanny/storage/app1
        # chown app1:keynanny /var/lib/keynanny/storage/app1

## Part 2: Configuring KeyNanny

### Configure the applications

- Copy the app1 confuration file to /etc/keynanny/

        # cp app1.conf /etc/keynanny/

### Encrypt the password(s)

This step can be done by root, the application owner or any
other user. As long as the KeyNanny certificates are available
it can be even done on a different machine. The KeyNanny 
certficates are not sensitive and can be shared with others
(think: public key).

- Use a certificate to excrypt a password

        # echo -n secret123 | openssl smime -encrypt -binary -aes256 -outform pem -out app1pw01 /var/lib/keynanny/crypto/kn02-cert.pem
        # cat app1pw01
        -----BEGIN PKCS7-----
        MIICLgYJKoZIhvcNAQcDoIICHzCCAhsCAQAxggHWMIIB0gIBADCBuTCBqzELMAkG
        A1UEBhMCU0UxEjAQBgNVBAgMCVRha2EgVHVrYTEdMBsGA1UEBwwUS2V5TmFubnkg
        VGVzdCBDZW50cmUxETAPBgNVBAoMCEtleU5hbm55MRQwEgYDVQQLDAtLZXlOYW5u
        eSBRQTEbMBkGA1UEAwwSS2V5TmFubnkgVGVzdCBIZXJvMSMwIQYJKoZIhvcNAQkB
        FhRrZXluYW5ueUBleGFtcGxlLmNvbQIJAN8k06FjKB3xMA0GCSqGSIb3DQEBAQUA
        BIIBACkwBi7F/5d9nXQE67kmNJZj7znxPaVJOy11oSK0bUVbm0VBIroF+RBHE5sW
        eTU9UqsDjdhtdm1lxLaM01x9SVYPyULpjXSOybYoHJtu65NMmKSVF3nXvwS4tisu
        293Dki/dtsxJ2UWZ9pncLlSMGs7L1j8biQo50RVSH9WgG0rWhSuwXOgt8RBN38K/
        Jnp8EKjavh/jq/ZhaQsnvKjNvqKsxt3kaaJTl5AMugCvE253ayTXo2FbtT7vjuD0
        yuP2aff3kM2CbYuwhJ7+CdmF4JP0AmtL84kIWQ1vrkStuxy6HQyLucRt1bpavsEc
        pe1KzwmUwLYS3g2nD2rA+FKEeCwwPAYJKoZIhvcNAQcBMB0GCWCGSAFlAwQBKgQQ
        a8/2KCsR/Q6XJs7rQt5irIAQqAwrOuYcp8BNzGBOBNrn3g==
        -----END PKCS7-----

- Optional: Try the reverse (Note: the echo at the end just adds a newline)

        # openssl smime -decrypt -aes256 -in app1pw01 -inform pem -recip /var/lib/keynanny/crypto/kn02-cert.pem -inkey /var/lib/keynanny/crypto/kn02-key.pem; echo
        secret123
        #

- Optional: See metadata of the encrypted password container (e.g. certificate/key info)

        # openssl cms -in app1pw01 -inform pem -cmsout -print

- Copy the encrypted password to /var/lib/keynanny/storage/app1 (world 
readable is OK, this data is not sensitive)

        # cp app1pw01 /var/lib/keynanny/storage/app1/
        # chown app1:keynanny /var/lib/keynanny/storage/app1/app1pw01
        # ll /var/lib/keynanny/storage/app1/
        -rw-r--r-- 1 app1 keynanny 806 Nov 18 19:58 app1pw01

## Part 3: Starting and testing KeyNanny

### Start KeyNanny

- Start the keynanny daemon

        # /etc/init.d/keynanny start
        Starting keynanny credential protection daemon: app1.
                                                                                  done
        #

- If everything is OK, you should see the socket. Notice that the
  socket is owned and only accessible by the application user.

        # ls -l /var/lib/keynanny/run/
        total 4
        -rw-r--r--. 1 app1 keynanny 6 Nov 18 20:55 app1.pid
        srw-------. 1 app1 keynanny 0 Nov 18 20:55 app1.socket

### Testing

- Switch to the application user

- Check that you can access keynanny

        # su - app1
        app1$ keynanny --socketfile /var/lib/keynanny/run/app1.socket get app1pw01; echo
        secret123

Finished. You have KeyNanny up and running and protecting your first secret.

