// MARK: Swiftgram
import Foundation
import Postbox
import SGSimpleSettings
import SGLogging

public var sgKeepDeletedMessagesEnabled: Bool {
    return SGSimpleSettings.shared.keepDeletedMessages
}

/// Decides whether a message that the server asked us to delete can stay in the
/// local history. Only regular cloud messages qualify: secret-chat, ephemeral,
/// scheduled and quick-reply messages are always removed for real, and so are
/// service (action) messages, which carry no user content worth preserving.
private func sgCanRetainDeletedMessage(_ message: Message) -> Bool {
    if message.id.namespace != Namespaces.Message.Cloud {
        return false
    }
    if message.id.peerId.namespace == Namespaces.Peer.SecretChat {
        return false
    }
    for media in message.media {
        if media is TelegramMediaAction {
            return false
        }
    }
    for attribute in message.attributes {
        // Self-destructing / auto-clearing content must honour its timer.
        if attribute is AutoremoveTimeoutMessageAttribute {
            return false
        }
        if attribute is AutoclearTimeoutMessageAttribute {
            return false
        }
    }
    return true
}

/// Marks the given messages with `SGDeletedMessageAttribute` instead of erasing
/// them. Returns the ids that were retained — the caller must delete everything
/// that is not in the returned set.
func sgRetainDeletedMessages(transaction: Transaction, ids: [MessageId]) -> Set<MessageId> {
    guard sgKeepDeletedMessagesEnabled, !ids.isEmpty else {
        return Set()
    }

    let timestamp = Int32(Date().timeIntervalSince1970)
    var retained = Set<MessageId>()

    for id in ids {
        guard let message = transaction.getMessage(id) else {
            continue
        }
        if message.sgIsDeleted {
            // Already marked by an earlier update — keep it as is.
            retained.insert(id)
            continue
        }
        if !sgCanRetainDeletedMessage(message) {
            continue
        }

        transaction.updateMessage(id, update: { currentMessage in
            var storeForwardInfo: StoreMessageForwardInfo?
            if let forwardInfo = currentMessage.forwardInfo {
                storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
            }
            var attributes = currentMessage.attributes
            attributes.removeAll(where: { $0 is SGDeletedMessageAttribute })
            attributes.append(SGDeletedMessageAttribute(date: timestamp))
            return .update(StoreMessage(id: currentMessage.id, customStableId: nil, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
        })
        retained.insert(id)
    }

    if !retained.isEmpty {
        SGLogger.shared.log("SGKeepDeletedMessages", "Retained \(retained.count) of \(ids.count) deleted message(s)")
    }

    return retained
}

public var sgSaveMessageEditHistoryEnabled: Bool {
    return SGSimpleSettings.shared.saveMessageEditHistory
}

/// Called while an incoming edit is being applied. Returns the revision list to
/// store on the updated message, or nil when nothing should change (feature off,
/// text unchanged, or the previous version is already recorded).
func sgAppendEditRevision(previousMessage: Message, updatedText: String) -> [SGMessageRevision]? {
    guard sgSaveMessageEditHistoryEnabled else {
        return nil
    }
    guard previousMessage.id.namespace == Namespaces.Message.Cloud else {
        return nil
    }
    guard previousMessage.text != updatedText else {
        return nil
    }
    guard !previousMessage.text.isEmpty else {
        return nil
    }

    var revisions = previousMessage.sgEditRevisions
    if let last = revisions.last, last.text == previousMessage.text {
        return nil
    }
    revisions.append(SGMessageRevision(text: previousMessage.text, date: previousMessage.editedTime ?? previousMessage.timestamp))
    if revisions.count > SGMessageEditHistoryAttribute.maximumRevisionCount {
        revisions.removeFirst(revisions.count - SGMessageEditHistoryAttribute.maximumRevisionCount)
    }
    return revisions
}
