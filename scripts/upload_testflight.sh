#!/bin/bash
# Uploads Iris to TestFlight. Run this AFTER re-authenticating Xcode:
#   Xcode → Settings → Accounts → basharlouzon@icloud.com → sign in again (password + 2FA)
set -euo pipefail
cd "$(dirname "$0")/.."

echo "▸ Archiving Iris (Release, sandboxed, team ARQ6W43L7C)…"
xcodebuild archive \
  -project Iris.xcodeproj \
  -scheme Iris \
  -configuration Release \
  -archivePath build/Iris.xcarchive \
  -allowProvisioningUpdates

echo "▸ Uploading to App Store Connect (TestFlight)…"
xcodebuild -exportArchive \
  -archivePath build/Iris.xcarchive \
  -exportOptionsPlist ExportOptions-appstore.plist \
  -authenticationKeyID 34Y39QQ4Z9 \
  -authenticationKeyIssuerID b56cbc46-54f9-4512-a691-11baccad691e \
  -authenticationKeyPath "$HOME/.appstoreconnect/private_keys/AuthKey_34Y39QQ4Z9.p8" \
  -allowProvisioningUpdates

echo "✓ Uploaded. Track processing at https://appstoreconnect.apple.com → Iris → TestFlight"
echo "  (First upload? The app record 'Iris' must exist in App Store Connect — see SHIP.md step 4.)"
