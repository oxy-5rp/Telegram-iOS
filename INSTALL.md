# Installing the build

The CI IPA is signed with the repository's fake codesigning material, which iOS
will not accept. It has to be re-signed with a certificate tied to an Apple
account before it will install. That step happens on your machine, with your
Apple ID — nobody can do it for you, because Apple issues the signing
certificate to the account, not to the file.

## What this build already does for you

A build re-signed with a **free** Apple ID cannot carry the App Group
entitlement (Apple only grants that to paid developer accounts). Stock
Telegram-iOS stops at an "Error 2" alert in that situation and never starts.
This build falls back to a private container instead, so it runs.

The trade-off: the app extensions (share sheet, notification service, widget)
get their own private containers and cannot see the main app's data. Sideloading
tools usually strip extensions anyway — a free Apple ID is limited to three
active apps, and each extension counts.

## Option 1 — AltServer (already installed on this machine)

1. Plug the iPhone in over USB and trust the computer.
2. Launch AltServer (tray icon) → **Install AltStore** → pick the device →
   sign in with your Apple ID. This puts AltStore on the phone.
3. Copy the IPA to the phone (AirDrop, iCloud Drive, or the Files app).
4. On the phone, open AltStore → **My Apps** → **+** → pick the IPA.

Free Apple ID caveats: the app expires after 7 days and AltStore must refresh
it (keep AltServer running and the phone on the same Wi-Fi), and you can have
at most three sideloaded apps at once.

## Option 2 — Sideloadly

Works the same way and tends to be more forgiving about entitlements. Point it
at the IPA, enter your Apple ID, hit Start. Under *Advanced options*, leaving
"Remove app extensions" checked is fine — see the trade-off above.

## Option 3 — TrollStore

If the device is on an iOS version TrollStore supports (roughly iOS 14.0 –
16.6.1, plus 17.0 on some chips), TrollStore installs unsigned IPAs permanently
with no Apple ID, no 7-day expiry and no three-app limit. Check
[TrollStore's compatibility list](https://github.com/opa334/TrollStore) against
the device's iOS version first.

## Option 4 — Paid Apple Developer account

A $99/year account signs the entitlements properly: App Groups work, extensions
work, and the app lasts a year instead of a week.

## The build needs its own api_id

Not just as a ban-risk precaution — **logging in does not work otherwise.**

Telegram asks official api_ids to prove they are the real app by answering a
silent APNs push: `setExternalRequestVerification` in `Network.swift` waits for a
`verify_nonce` / `verify_secret` payload delivered through
`didReceiveRemoteNotification`. A build re-signed with a free Apple ID has no
`aps-environment` entitlement, never registers with APNs, and so never receives
that push. The wait times out after 15 seconds, `auth.sendCode` then dies on its
own 20-second timeout, and the login screen says *"Please check your internet
connection"* — with a perfectly healthy network. Third-party api_ids are not
asked for this at all.

Get credentials from [my.telegram.org](https://my.telegram.org) (API development
tools) and add them to the repository's **Actions secrets** as `TG_API_ID` and
`TG_API_HASH`. The workflow substitutes them into the build configuration at
build time. They live in secrets rather than in the committed configuration on
purpose: an `api_hash` does not belong in git.
