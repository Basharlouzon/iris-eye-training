# Shipping Iris — App Store & TestFlight guide

The build system is already wired: `scripts/upload_testflight.sh` archives
(sandboxed, team ARQ6W43L7C) and uploads straight to TestFlight. Everything in
this file marked **[you]** needs your Apple ID — no tool can do those steps for
you, they require your password + 2FA.

## Status snapshot

| Step | State |
|---|---|
| Archive (Release, sandboxed, entitlements) | ✅ `xcodebuild archive` succeeds — `build/Iris.xcarchive` |
| Signing | ✅ Apple Development cert in keychain (team ARQ6W43L7C) |
| App Sandbox + entitlements | ✅ `Configuration/Iris.entitlements` (sandbox, Apple Events, network client) |
| Privacy manifest | ✅ `resources/PrivacyInfo.xcprivacy` (no tracking, no collected data, UserDefaults CA92.1) |
| Export-compliance | ✅ `ITSAppUsesNonExemptEncryption = false` in Info.plist |
| Xcode session | ⚠️ **expired** — `basharlouzon@icloud.com` needs re-auth |
| App Store Connect app record | ❓ unknown — create once if missing |
| TestFlight public link | ❓ **[you]** after first upload + Beta App Review |

## Step-by-step

### 1. [you] Re-authenticate Xcode

The last upload failed with `Invalid credentials in keychain for
basharlouzon@icloud.com, missing Xcode-Token`.

- Open **Xcode → Settings → Accounts**
- Select `basharlouzon@icloud.com` → sign in again (password + 2FA)

### 2. [you, once] Register the app in App Store Connect

Only needed if "Iris" isn't there yet: [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
→ **Apps → + → New App**

- Name: `Iris` · Language: English · Bundle ID: `com.basharlouzon.Iris`
- SKU: `iris-1` · Access: Full access

### 3. Upload

```bash
chmod +x scripts/upload_testflight.sh
./scripts/upload_testflight.sh
```

Because your team's App Store Connect API key is configured in Xcode, this
signs, versions (auto-increments the build number), and uploads in one go.
If it says *"No suitable application records were found"* → do step 2 first.

### 4. TestFlight

After upload, the build processes for ~10–30 min at
**App Store Connect → Iris → TestFlight**.

- **Yourself:** add yourself as an *internal tester* → install TestFlight from
  the MAS → build appears immediately after processing. No review needed.
- **Shareable public link [you]:** TestFlight → your build → *TestFlight
  groups* → **+ → New Group** ("Public Beta") → add the build → group page →
  **Enable Public Link**. That URL is the shareable TestFlight link.
  External builds need: a privacy-policy URL (use the hosted version of
  `App/privacy-policy.md` — a public GitHub gist/page works) and to pass
  **Beta App Review** (usually a few hours to a day).

### 5. App Privacy questionnaire

App Store Connect → Iris → **App Privacy**: answer "No data collected"
(matching `PrivacyInfo.xcprivacy`). Music control is a *permission*, not data
collection — nothing leaves the device.

## App Store review notes (paste when submitting for release)

> Iris is a menu-bar eye-care utility. It shows break reminders following the
> 20-20-20 rule, plays guided eye-exercise animations, and can show the current
> Apple Music track with transport controls (using the standard Automation
> permission, requested in-app). It collects no data and has no account system.

Known review-risk areas: Apple Events to Music (allowed via
`com.apple.security.automation.apple-events` + user consent), and the
screenSaver-level notch panel (notch apps exist on the MAS; expect a question
about it — the panel only appears on user action).

## No-account fallback (share today, no Apple review)

`build/Iris.xcarchive` → zip `Iris.app` → send the zip. Recipients
right-click → Open once (Gatekeeper). Unsigned/ad-hoc builds work on any Mac
but show a Gatekeeper warning; Developer ID + notarization removes that and
needs the same paid team.
