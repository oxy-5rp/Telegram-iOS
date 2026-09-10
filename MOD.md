# Mod notes

A fork of [Swiftgram](https://github.com/Swiftgram/Telegram-iOS) with AyuGram-style
privacy and history features added on the `sg-keep-deleted-messages` branch.

Everything below is **off by default** and lives in Swiftgram Settings.
All added code is marked with `// MARK: Swiftgram` comments.

## Keep Deleted Messages

Settings ▸ Other ▸ *Keep Deleted Messages*

Messages deleted by other people stay in the chat and get a 🗑 marker next to
their timestamp instead of disappearing.

- `submodules/TelegramCore/Sources/SyncCore/SyncCore_SGDeletedMessageAttribute.swift`
  — the persistent `SGDeletedMessageAttribute` and `Message.sgIsDeleted`.
- `submodules/TelegramCore/Sources/State/SGKeepDeletedMessages.swift`
  — the retention policy.
- `submodules/TelegramCore/Sources/State/AccountStateManagementUtils.swift`
  — the `.DeleteMessages` / `.DeleteMessagesWithGlobalIds` replay branches run
  ids through the retention pass and only delete what was not retained.
- `submodules/TelegramUI/.../StringForMessageTimestampStatus.swift`
  — the marker, added in the one funnel every bubble's status line goes through.

**Deliberately still deleted for real:** secret-chat messages, ephemeral /
self-destructing messages, scheduled and quick-reply messages, service (action)
messages, and anything carrying an autoremove or autoclear timer. Clearing a
history yourself also still clears it — that goes through a different code path.

## Ghost Mode

Settings ▸ Ghost Mode — a master toggle plus four sub-options. Each sub-option
only applies while the master toggle is on.

| Option | What is skipped |
| --- | --- |
| Don't Send Read Receipts | `messages.readHistory` / `channels.readHistory` and media "viewed" marks. Chats still read locally. |
| Don't Send Online Status | `account.updateStatus` never reports online. |
| Don't Send Typing Status | `messages.setTyping`. |
| Don't Mark Stories as Seen | `stories.readStories` and `stories.incrementStoryViews`. |

**Known gap:** mention and reaction read marks
(`ManagedConsumePersonalMessagesActions`) are still reported, because there the
local state update is coupled to the network response and short-circuiting it
would loop the pending action. Sending a message or reacting still puts you
online — that is a server-side effect, not something the client can suppress.

## Save Message History

Settings ▸ Other ▸ *Save Message History*

When an incoming edit arrives, the superseded text is kept on the message (up to
32 revisions). Messages that have revisions get an *Edit History* context-menu
entry that renders every version, plus the current text, as a text document.

- `submodules/TelegramCore/Sources/SyncCore/SyncCore_SGMessageEditHistoryAttribute.swift`
- `submodules/TelegramUI/Sources/SGMessageEditHistory.swift`

## Don't Notify About Screenshots

Settings ▸ Ghost Mode ▸ *Don't Notify About Screenshots*

Taking a screenshot of a secret chat or of self-destructing media no longer
posts the "took a screenshot" service message. Hooked at
`_internal_addSecretChatMessageScreenshot`, which all three call sites funnel
through, plus the secret media preview's own cloud-chat branch.

## Ignore Copy Protection

Settings ▸ Other ▸ *Ignore Copy Protection*

Chats with forwarding/saving restricted behave like unrestricted ones locally:
`Message.isCopyProtected()` and the chat-level flag both report false.

## Hide Sponsored Messages

Settings ▸ Other ▸ *Hide Sponsored Messages* — short-circuits
`messages.getSponsoredMessages`, so no ads are produced for any chat.

## Message Filters

Settings ▸ Message Filters

Add a word or a regular expression; any message whose text matches is left out
of the chat entirely — it is dropped in `chatHistoryEntriesForView`, the one
place every chat entry passes through, so there is no placeholder row. Tap a
filter to remove it. Patterns are matched case-insensitively; an invalid
pattern is dropped rather than matched literally.

- `submodules/TelegramUI/Sources/SGMessageFilters.swift` — the matcher, with the
  compiled expressions cached against the stored pattern string.

A pattern written as a tag matches an attachment instead of text — `<photo>`,
`<video>`, `<gif>`, `<sticker>`, `<voice>`, `<round>`, `<audio>`, `<file>`,
`<poll>`, `<contact>`, `<location>`, `<link>`, `<button>`, `<forward>`,
`<reply>`. An unrecognised tag is compiled as a regex, so a literal `<b>` still
does what it looks like.

*Hide Messages From Blocked Users* in the same section drops every message whose
author you have blocked. The blocked list is paginated and main-queue bound, so
`SGBlockedPeersCache` pages through it once at launch and caches the ids for the
layout path; the setting therefore takes effect after a restart.

Per-chat filter scoping is not implemented — a filter applies everywhere.

## Keep Chats You Left

Settings ▸ Other ▸ *Keep Chats You Left*

Groups and channels you left or were removed from stay in the chat list instead
of disappearing. `shouldExcludePeerFromChatList` is the single funnel for that
decision. Groups that were deactivated outright are still excluded.

## Local Premium

Settings ▸ Other ▸ *Local Premium*

Reports the account as Premium to the app itself, which unlocks the limits and
gates the client enforces on its own (`AccountContext.isPremium` and the user
limits configuration derived from it). Anything the **server** checks — upload
size, saved GIF count, premium reactions, stickers — is unaffected, because the
server knows the truth. This is a client-side unlock, not a subscription.

## Keep Self-Destructing Media

Settings ▸ Other ▸ *Keep Self-Destructing Media*

View-once photos and videos stay in the chat instead of being replaced by an
expired-content placeholder. The scheduled expiry entry is cleared from the
timestamp table so it is not retried in a loop, and the message itself is left
untouched.

Scope: cloud self-destructing media only (`AutoclearTimeoutMessageAttribute`,
autoremove tag 1). Secret-chat TTL and a chat's own auto-delete timer
(`AutoremoveTimeoutMessageAttribute`, tag 0) still delete as normal — those are
timers you or the chat set, not a one-time view.

## Show Message ID

Settings ▸ Other ▸ *Show Message ID*

Prefixes each message's status line with `#<id>`, through the same funnel as the
deleted-message marker.

## Building

CI: `.github/workflows/sg-build.yml` builds `release_arm64` on a macOS runner
and uploads `Telegram.ipa` as a run artifact. It uses
`build-system/sg-ci-configuration.json`, which is the stock appstore
configuration plus the `sg_config` key the Swiftgram fork's build system
requires.

The IPA is signed with the repo's fake codesigning material, so it needs to be
re-signed (AltStore, Sideloadly, or your own developer certificate) before it
will install on a device. The bundled `api_id` is Telegram's public one — swap
in your own in `build-system/sg-ci-configuration.json` before using the build
with a real account.
