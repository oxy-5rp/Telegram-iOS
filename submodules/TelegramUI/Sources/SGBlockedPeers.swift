// MARK: Swiftgram
import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore
import SGSimpleSettings

/// Set of blocked peer ids, kept so the chat history builder can drop their
/// messages without touching the database on the layout path.
///
/// `BlockedPeersContext` is paginated and main-queue bound, so this pages
/// through it once per account and caches the result behind a lock. It is only
/// populated when the "Hide Blocked Users" setting is on at launch — toggling
/// the setting asks for a restart, like the other settings that change what the
/// app subscribes to at startup.
public final class SGBlockedPeersCache {
    public static let shared = SGBlockedPeersCache()

    private let lock = NSLock()
    private var blockedIds = Set<PeerId>()

    // Main-queue only.
    private var accountPeerId: PeerId?
    private var context: BlockedPeersContext?
    private var disposable: Disposable?

    public func setup(account: Account) {
        Queue.mainQueue().async { [weak self] in
            guard let self else {
                return
            }
            guard SGSimpleSettings.shared.hideBlockedUsers else {
                return
            }
            if self.accountPeerId == account.peerId {
                return
            }

            self.disposable?.dispose()
            self.accountPeerId = account.peerId
            self.lock.lock()
            self.blockedIds = Set()
            self.lock.unlock()

            let context = BlockedPeersContext(account: account, subject: .blocked)
            self.context = context
            self.disposable = (context.state
            |> deliverOnMainQueue).start(next: { [weak self, weak context] state in
                guard let self else {
                    return
                }
                self.lock.lock()
                self.blockedIds = Set(state.peers.map { $0.peerId })
                self.lock.unlock()

                // The list arrives a page at a time; keep pulling until it ends,
                // otherwise only the first page would ever be hidden.
                if state.canLoadMore && !state.isLoadingMore {
                    context?.loadMore()
                }
            })
        }
    }

    func contains(_ peerId: PeerId) -> Bool {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.blockedIds.contains(peerId)
    }
}
