// MARK: Swiftgram
import Foundation
import Postbox

/// One superseded version of a message's text, captured when an edit arrives.
public final class SGMessageRevision: PostboxCoding, Equatable {
    public let text: String
    /// Unix timestamp this version was live until (the message's edit/send date).
    public let date: Int32

    public init(text: String, date: Int32) {
        self.text = text
        self.date = date
    }

    public init(decoder: PostboxDecoder) {
        self.text = decoder.decodeStringForKey("t", orElse: "")
        self.date = decoder.decodeInt32ForKey("d", orElse: 0)
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.text, forKey: "t")
        encoder.encodeInt32(self.date, forKey: "d")
    }

    public static func ==(lhs: SGMessageRevision, rhs: SGMessageRevision) -> Bool {
        return lhs.text == rhs.text && lhs.date == rhs.date
    }
}

/// Previous versions of an edited message, oldest first. Only kept while the
/// "Save Message History" mod setting is on.
public class SGMessageEditHistoryAttribute: MessageAttribute {
    /// Hard cap so a message that is edited in a loop cannot grow without bound.
    public static let maximumRevisionCount: Int = 32

    public let revisions: [SGMessageRevision]

    public init(revisions: [SGMessageRevision]) {
        self.revisions = revisions
    }

    required public init(decoder: PostboxDecoder) {
        self.revisions = decoder.decodeObjectArrayWithDecoderForKey("r")
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.revisions, forKey: "r")
    }
}

public extension Message {
    var sgEditRevisions: [SGMessageRevision] {
        for attribute in self.attributes {
            if let attribute = attribute as? SGMessageEditHistoryAttribute {
                return attribute.revisions
            }
        }
        return []
    }
}
