// MARK: Swiftgram
import Foundation
import Postbox
import TelegramCore
import SGSimpleSettings

/// A message trait a filter can match on, written as `<photo>`, `<video>` and so
/// on in the filter list. Anything that is not one of these is treated as a
/// regular expression over the message text.
private enum SGMessageFilterKind: String, CaseIterable {
    case photo
    case video
    case gif
    case sticker
    case voice
    case round
    case audio
    case file
    case poll
    case contact
    case location
    case link
    case button
    case forward
    case reply

    func matches(_ message: Message) -> Bool {
        switch self {
        case .photo:
            return message.media.contains(where: { $0 is TelegramMediaImage })
        case .video:
            return message.media.contains(where: { ($0 as? TelegramMediaFile)?.isVideo == true })
        case .gif:
            return message.media.contains(where: { ($0 as? TelegramMediaFile)?.isAnimated == true })
        case .sticker:
            return message.media.contains(where: { ($0 as? TelegramMediaFile)?.isSticker == true })
        case .voice:
            return message.media.contains(where: { ($0 as? TelegramMediaFile)?.isVoice == true })
        case .round:
            return message.media.contains(where: { ($0 as? TelegramMediaFile)?.isInstantVideo == true })
        case .audio:
            return message.media.contains(where: { ($0 as? TelegramMediaFile)?.isMusic == true })
        case .file:
            return message.media.contains(where: { media in
                guard let file = media as? TelegramMediaFile else {
                    return false
                }
                return !file.isVideo && !file.isAnimated && !file.isSticker && !file.isVoice && !file.isInstantVideo && !file.isMusic
            })
        case .poll:
            return message.media.contains(where: { $0 is TelegramMediaPoll })
        case .contact:
            return message.media.contains(where: { $0 is TelegramMediaContact })
        case .location:
            return message.media.contains(where: { $0 is TelegramMediaMap })
        case .link:
            return message.media.contains(where: { $0 is TelegramMediaWebpage })
        case .button:
            return message.attributes.contains(where: { $0 is ReplyMarkupMessageAttribute })
        case .forward:
            return message.forwardInfo != nil
        case .reply:
            return message.attributes.contains(where: { $0 is ReplyMessageAttribute })
        }
    }
}

/// Compiled form of the user's filter list.
///
/// The list is stored as newline-separated patterns, so it is re-compiled only
/// when that string changes. `chatHistoryEntriesForView` consults this for every
/// message it lays out, off the main thread, hence the lock.
private final class SGMessageFilterCache {
    static let shared = SGMessageFilterCache()

    struct Compiled {
        var kinds: [SGMessageFilterKind] = []
        var expressions: [NSRegularExpression] = []

        var isEmpty: Bool {
            return self.kinds.isEmpty && self.expressions.isEmpty
        }
    }

    private let lock = NSLock()
    private var compiledSource: String?
    private var compiled = Compiled()

    func compile(for source: String) -> Compiled {
        self.lock.lock()
        defer { self.lock.unlock() }

        if self.compiledSource == source {
            return self.compiled
        }

        var result = Compiled()
        for line in source.components(separatedBy: "\n") {
            let pattern = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if pattern.isEmpty {
                continue
            }
            if pattern.hasPrefix("<"), pattern.hasSuffix(">") {
                let name = String(pattern.dropFirst().dropLast()).lowercased()
                if let kind = SGMessageFilterKind(rawValue: name) {
                    result.kinds.append(kind)
                    continue
                }
                // An unknown <tag> falls through and is compiled as a regex, which
                // is what a user who meant it literally would expect.
            }
            // An invalid pattern is dropped rather than treated as literal text:
            // silently matching something the user did not intend is worse than
            // the filter having no effect.
            if let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                result.expressions.append(expression)
            }
        }

        self.compiledSource = source
        self.compiled = result
        return result
    }
}

/// True when the message matches any filter and should be left out of the chat
/// entirely.
func sgShouldHideMessage(_ message: Message) -> Bool {
    let source = SGSimpleSettings.shared.messageFilters
    if source.isEmpty {
        return false
    }
    let compiled = SGMessageFilterCache.shared.compile(for: source)
    if compiled.isEmpty {
        return false
    }

    for kind in compiled.kinds {
        if kind.matches(message) {
            return true
        }
    }

    let text = message.text
    if text.isEmpty || compiled.expressions.isEmpty {
        return false
    }
    let range = NSRange(text.startIndex ..< text.endIndex, in: text)
    for expression in compiled.expressions {
        if expression.firstMatch(in: text, options: [], range: range) != nil {
            return true
        }
    }
    return false
}
