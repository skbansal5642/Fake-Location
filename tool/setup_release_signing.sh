#!/usr/bin/env bash
# Creates (or reuses) the release signing keystore and stores it as GitHub secrets
# for the Release workflow. Run once from the project root:
#   tool/setup_release_signing.sh [path/to/keystore.jks]
set -euo pipefail

REPO="skbansal5642/Fake-Location"
KEYSTORE="${1:-$HOME/.android-keys/fake-location-upload.jks}"
ALIAS="upload"

command -v keytool >/dev/null || { echo "keytool not found; install a JDK." >&2; exit 1; }
command -v gh >/dev/null || { echo "gh (GitHub CLI) not found." >&2; exit 1; }

if [[ -f "$KEYSTORE" ]]; then
  echo "Using existing keystore: $KEYSTORE"
else
  mkdir -p "$(dirname "$KEYSTORE")"
  echo "Creating keystore: $KEYSTORE"
  echo "keytool will ask for a password and your name/organization."
  keytool -genkeypair -v -keystore "$KEYSTORE" -alias "$ALIAS" \
    -keyalg RSA -keysize 2048 -validity 10000 -storetype PKCS12
fi

read -rsp "Keystore password: " STORE_PASSWORD
echo
# Fails here if the password is wrong, before anything is uploaded.
keytool -list -keystore "$KEYSTORE" -storepass "$STORE_PASSWORD" -alias "$ALIAS" >/dev/null

base64 < "$KEYSTORE" | tr -d '\n' | gh secret set ANDROID_KEYSTORE_BASE64 --repo "$REPO"
printf '%s' "$STORE_PASSWORD" | gh secret set ANDROID_KEYSTORE_PASSWORD --repo "$REPO"
printf '%s' "$ALIAS" | gh secret set ANDROID_KEY_ALIAS --repo "$REPO"
# PKCS12 keystores use the store password for the key as well.
printf '%s' "$STORE_PASSWORD" | gh secret set ANDROID_KEY_PASSWORD --repo "$REPO"

echo
echo "Secrets saved to $REPO."
echo "Back up $KEYSTORE and its password somewhere safe: without them you cannot"
echo "publish updates that install over existing versions of the app."
