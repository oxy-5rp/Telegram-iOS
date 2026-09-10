// MARK: Swiftgram
import Foundation
import Postbox
import TelegramCore
import SGSimpleSettings

/// Compiled form of the user's filter list.
///
/// The list is stored as newline-separated patterns, so it is re-compiled only
/// when that string changes. `chatHistoryEntriesForView` consults this for every
/// message it lays out, off the main thread, hence the lock.
private final class SGMessageFilterCache {
    static let shared = SGMessageFilterCache()

    private let lock = NSLock()
    private var compiledSource: String?
    private var compiledExpressions: [NSRegularExpression] = []

    func expressions(for source: String) -> [NSRegularExpression] {
        self.lock.lock()
        defer { self.lock.unlock() }

        if self.compiledSource == source {
            return self.compiledExpressions
        }

        var result: [NSRegularExpression] = []
        for line in source.components(separatedBy: "\n") {
            let pattern = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if pattern.isEmpty {
                continue
            }
            // An invalid pattern is dropped rather than treated as literal text:
            // silently matching something the user did not intend is worse than
            // the filter having no effect.
            if let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                result.append(expression)
            }
        }

        self.compiledSource = source
        self.compiledExpressions = result
        return result
    }
}

/// True when the message text matches any filter and the message should be
/// left out of the chat entirely.
func sgShouldHideMessage(_ message: Message) -> Bool {
    let source = SGSimpleSettings.shared.messageFilters
    if source.isEmpty {
        return false
    }
    let text = message.text
    if text.isEmpty {
        return false
    }
    let expressions = SGMessageFilterCache.shared.expressions(for: source)
    if expressions.isEmpty {
        return false
    }
    let range = NSRange(text.startIndex ..< text.endIndex, in: text)
    for expression in expressions {
        if expression.firstMatch(in: text, options: [], range: range) != nil {
            return true
        }
    }
    return false
}
