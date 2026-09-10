// MARK: Swiftgram
import Foundation

/// Container used when the App Group entitlement is unavailable.
///
/// Sideloaded builds re-signed with a free Apple ID cannot carry
/// `com.apple.security.application-groups` — Apple only issues that to paid
/// developer accounts — so `containerURL(forSecurityApplicationGroupIdentifier:)`
/// returns nil and the app would otherwise stop at the "Error 2" alert before
/// it ever starts.
///
/// Falling back to a directory inside the app's own container keeps the app
/// fully usable on its own. The app extensions (share sheet, notification
/// service, widget) each get their own private container in that situation and
/// therefore cannot see the main app's data — that is inherent to not having a
/// shared container, and is why this is only a fallback.
func sgFallbackAppGroupUrl() -> URL? {
    guard let libraryUrl = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else {
        return nil
    }
    let fallbackUrl = libraryUrl.appendingPathComponent("SGAppGroupFallback", isDirectory: true)
    if !FileManager.default.fileExists(atPath: fallbackUrl.path) {
        do {
            try FileManager.default.createDirectory(at: fallbackUrl, withIntermediateDirectories: true, attributes: nil)
        } catch {
            return nil
        }
    }
    return fallbackUrl
}

/// True when the process actually has a shared container for `identifier`.
func sgHasAppGroupContainer(_ identifier: String) -> Bool {
    return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) != nil
}
