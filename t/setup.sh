#!/bin/bash

mkdir -p tmp/crypto/
mkdir -p tmp/storage/

# Initial key
openssl req -x509 -passout pass:1234 -newkey rsa:2048 -keyout tmp/crypto/keynanny-key.pem -days 365 -subj "/CN=Encryption Cert/O=KeyNanny/C=DE" -out tmp/crypto/keynanny-cert.pem

echo secret | openssl smime -encrypt -binary -aes256 -out tmp/storage/foo -outform pem  tmp/crypto/keynanny-cert.pem
echo othersecret | openssl smime -encrypt -binary -aes256 -out tmp/storage/bar -outform pem  tmp/crypto/keynanny-cert.pem

bin/keynannyd --config t/keynanny.conf


