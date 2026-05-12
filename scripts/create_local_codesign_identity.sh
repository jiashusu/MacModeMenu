#!/usr/bin/env bash
set -euo pipefail

IDENTITY="${MACMODEMENU_CODESIGN_IDENTITY:-MacModeMenu Local Code Signing}"
KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"
P12_PASSWORD="macmodemenu-local"
SHOULD_TRUST="false"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

if [[ "${1:-}" == "--trust" ]]; then
    SHOULD_TRUST="true"
fi

if security find-identity -v -p codesigning | grep -Fq "$IDENTITY"; then
    echo "Code signing identity already exists: $IDENTITY"
    exit 0
fi

security delete-certificate -c "$IDENTITY" "$KEYCHAIN" >/dev/null 2>&1 || true

cat >"$WORKDIR/cert.conf" <<EOF
[ req ]
distinguished_name = req_distinguished_name
x509_extensions = v3_codesign
prompt = no

[ req_distinguished_name ]
CN = $IDENTITY

[ v3_codesign ]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = codeSigning
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
EOF

openssl req \
    -x509 \
    -newkey rsa:2048 \
    -sha256 \
    -days 3650 \
    -nodes \
    -keyout "$WORKDIR/codesign.key" \
    -out "$WORKDIR/codesign.crt" \
    -config "$WORKDIR/cert.conf"

openssl pkcs12 \
    -export \
    -legacy \
    -inkey "$WORKDIR/codesign.key" \
    -in "$WORKDIR/codesign.crt" \
    -name "$IDENTITY" \
    -out "$WORKDIR/codesign.p12" \
    -passout "pass:$P12_PASSWORD"

security import "$WORKDIR/codesign.p12" \
    -k "$KEYCHAIN" \
    -P "$P12_PASSWORD" \
    -A

if [[ "$SHOULD_TRUST" == "true" ]]; then
    security add-trusted-cert \
        -d \
        -r trustRoot \
        -p codeSign \
        -k "$KEYCHAIN" \
        "$WORKDIR/codesign.crt"
fi

echo "Imported local code signing certificate: $IDENTITY"
if security find-identity -v -p codesigning | grep -Fq "$IDENTITY"; then
    echo "Code signing identity is ready. Now run scripts/package_app.sh and grant Screen Recording once more."
else
    echo "The certificate is imported but not trusted yet, so macOS does not expose it as a valid code signing identity."
    echo "Open Keychain Access, find '$IDENTITY', set Trust > Code Signing to Always Trust, then run scripts/package_app.sh."
    echo "Alternatively run: scripts/create_local_codesign_identity.sh --trust and approve the macOS trust prompt."
fi
