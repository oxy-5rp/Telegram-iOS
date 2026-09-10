// MARK: Swiftgram
import Foundation

/// Entitlements granted to this build, read from the embedded provisioning
/// profile.
///
/// Re-signing an IPA with a free Apple ID strips the entitlements that account
/// cannot issue — iCloud among them — while the compiled code still believes the
/// features are available. `CKContainer.default()` traps rather than failing in
/// that situation, which crashes the app on launch, so the code has to ask
/// before touching CloudKit.
private func sgProvisioningProfileEntitlements() -> [String: Any]? {
    guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision") else {
        return nil
    }
    guard let data = try? Data(contentsOf: url) else {
        return nil
    }
    // The profile is CMS-signed with the plist embedded as plain XML.
    guard let start = data.range(of: Data("<?xml".utf8)) else {
        return nil
    }
    guard let end = data.range(of: Data("</plist>".utf8), options: [.backwards]) else {
        return nil
    }
    let plistData = data.subdata(in: start.lowerBound ..< end.upperBound)
    guard let object = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) else {
        return nil
    }
    guard let plist = object as? [String: Any] else {
        return nil
    }
    return plist["Entitlements"] as? [String: Any]
}

private let sgHasICloudContainerEntitlementValue: Bool = {
    guard let entitlements = sgProvisioningProfileEntitlements() else {
        // No readable profile: a simulator build, or a store build whose profile
        // we could not parse. Both of those do have the entitlement when it was
        // compiled in, so assume it rather than disabling the feature for
        // everyone.
        return true
    }
    guard let containers = entitlements["com.apple.developer.icloud-container-identifiers"] as? [String] else {
        return false
    }
    return !containers.isEmpty
}()

/// True when this build may talk to CloudKit.
func sgHasICloudContainerEntitlement() -> Bool {
    return sgHasICloudContainerEntitlementValue
}
