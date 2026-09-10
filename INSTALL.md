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

## Before logging into a real account

The build carries Telegram's public `api_id`. Get your own from
[my.telegram.org](https://my.telegram.org) and put it in
`build-system/sg-ci-configuration.json` (`api_id` / `api_hash`), then rebuild.
Third-party clients using someone else's `api_id` can get the account limited.
