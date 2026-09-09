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

## Hide Sponsored Messages

Settings ▸ Other ▸ *Hide Sponsored Messages* — short-circuits
`messages.getSponsoredMessages`, so no ads are produced for any chat.

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
