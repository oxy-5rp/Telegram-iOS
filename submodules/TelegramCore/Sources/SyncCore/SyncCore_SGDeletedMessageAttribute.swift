// MARK: Swiftgram
import Foundation
import Postbox

/// Marks a message that was deleted remotely but kept locally by the
/// "Keep Deleted Messages" mod. The message stays in the history and is
/// rendered with a trash marker instead of disappearing.
public class SGDeletedMessageAttribute: MessageAttribute {
    /// Unix timestamp of the moment the deletion update was received.
    public let date: Int32

    public init(date: Int32) {
        self.date = date
    }

    required public init(decoder: PostboxDecoder) {
        self.date = decoder.decodeInt32ForKey("d", orElse: 0)
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.date, forKey: "d")
    }
}

public extension Message {
    var sgDeletedTimestamp: Int32? {
        for attribute in self.attributes {
            if let attribute = attribute as? SGDeletedMessageAttribute {
                return attribute.date
            }
        }
        return nil
    }

    var sgIsDeleted: Bool {
        return self.sgDeletedTimestamp != nil
    }
}

public extension EngineMessage {
    var sgDeletedTimestamp: Int32? {
        for attribute in self.attributes {
            if let attribute = attribute as? SGDeletedMessageAttribute {
                return attribute.date
            }
        }
        return nil
    }

    var sgIsDeleted: Bool {
        return self.sgDeletedTimestamp != nil
    }
}
