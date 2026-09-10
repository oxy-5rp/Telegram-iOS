// MARK: Swiftgram
import Foundation

/// Entitlements granted to this build, read from the embedded provisioning
/// profile.
///
/// Re-signing an IPA with a free Apple ID strips the entitlements that account
/// cannot issue — iCloud among them — while the compiled code still believes the
/// features are available. Some of those APIs trap rather than fail:
/// `CKContainer.default()` and `NSUbiquitousKeyValueStore.default` both take the
/// process down instead of returning nil, so the code has to ask first.
private let sgProvisioningProfileEntitlements: [String: Any]? = {
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
}()

/// No readable profile means a simulator build, or a store build whose profile
/// could not be parsed. Both of those do carry the entitlement when it was
/// compiled in, so assume it is present rather than disabling the feature for
/// every normal install.
private func sgHasEntitlement(_ key: String, isNonEmpty: (Any) -> Bool) -> Bool {
    guard let entitlements = sgProvisioningProfileEntitlements else {
        return true
    }
    guard let value = entitlements[key] else {
        return false
    }
    return isNonEmpty(value)
}

private let sgHasICloudContainerEntitlementValue: Bool = sgHasEntitlement("com.apple.developer.icloud-container-identifiers", isNonEmpty: { value in
    guard let containers = value as? [String] else {
        return false
    }
    return !containers.isEmpty
})

private let sgHasUbiquityKeyValueStoreEntitlementValue: Bool = sgHasEntitlement("com.apple.developer.ubiquity-kvstore-identifier", isNonEmpty: { value in
    guard let identifier = value as? String else {
        return false
    }
    return !identifier.isEmpty
})

/// True when this build may talk to CloudKit.
func sgHasICloudContainerEntitlement() -> Bool {
    return sgHasICloudContainerEntitlementValue
}

/// The iCloud key-value store, or nil when this build is not entitled to one.
/// Reading `NSUbiquitousKeyValueStore.default` without the entitlement raises.
func sgUbiquitousKeyValueStore() -> NSUbiquitousKeyValueStore? {
    guard sgHasUbiquityKeyValueStoreEntitlementValue else {
        return nil
    }
    return NSUbiquitousKeyValueStore.default
}
