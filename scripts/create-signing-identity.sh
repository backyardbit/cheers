#!/usr/bin/env bash
set -euo pipefail

NAME="Cheers Local Signing"

if security find-identity -p codesigning | grep -q "$NAME"; then
    echo "\"$NAME\" already exists."
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/cert.conf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$WORK/key.pem" -out "$WORK/cert.pem" -config "$WORK/cert.conf"
/usr/bin/openssl pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
    -out "$WORK/identity.p12" -passout pass:cheers -name "$NAME"

security import "$WORK/identity.p12" -k ~/Library/Keychains/login.keychain-db \
    -P cheers -T /usr/bin/codesign
security add-trusted-cert -r trustRoot -p codeSign -k ~/Library/Keychains/login.keychain-db "$WORK/cert.pem"

echo "Created \"$NAME\". Rebuild with scripts/build-app.sh."
