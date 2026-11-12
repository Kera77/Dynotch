#!/usr/bin/env bash
# Uploads the Developer ID signing + notarization secrets to the GitHub repo.
# Run locally, interactively. Nothing is written to disk or echoed.
#
# Usage: ./scripts/setup-signing-secrets.sh path/to/DeveloperID.p12
set -euo pipefail

P12="${1:?Usage: $0 path/to/DeveloperID.p12}"
[[ -f "$P12" ]] || { echo "File not found: $P12"; exit 1; }

gh auth status >/dev/null

read -rsp ".p12 password: " CERT_PASSWORD; echo
read -rp  "Signing identity (e.g. Developer ID Application: Name (TEAMID)): " IDENTITY
read -rp  "Apple Team ID (10 chars): " TEAM_ID
read -rp  "Apple ID e-mail: " APPLE_ID
read -rsp "App-specific password (xxxx-xxxx-xxxx-xxxx): " APP_PASSWORD; echo

# Sanity check: the identity must actually be in the .p12
if ! openssl pkcs12 -in "$P12" -passin "pass:$CERT_PASSWORD" -nokeys -legacy 2>/dev/null \
     | grep -q "Developer ID Application" \
   && ! openssl pkcs12 -in "$P12" -passin "pass:$CERT_PASSWORD" -nokeys 2>/dev/null \
     | grep -q "Developer ID Application"; then
  echo "error: no 'Developer ID Application' certificate found in $P12 (wrong password or wrong cert type)"
  exit 1
fi

base64 -i "$P12" | gh secret set DEVELOPER_ID_CERT_P12
printf '%s' "$CERT_PASSWORD" | gh secret set DEVELOPER_ID_CERT_PASSWORD
printf '%s' "$IDENTITY"      | gh secret set DEVELOPER_ID_APPLICATION
printf '%s' "$TEAM_ID"       | gh secret set APPLE_TEAM_ID
printf '%s' "$APPLE_ID"      | gh secret set APPLE_ID
printf '%s' "$APP_PASSWORD"  | gh secret set APPLE_APP_PASSWORD

echo "Secrets set:"; gh secret list
