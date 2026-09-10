import Foundation
import BuildConfig

public struct SGConfig: Codable {
    public enum CodingKeys: String, CodingKey {
        case apiUrl
        case webappUrl
        case botUsername
        case publicKey
        case iaps
        case useTestServer
    }

    public var apiUrl: String = "https://api.swiftgram.app"
    public var webappUrl: String = "https://my.swiftgram.app"
    public var botUsername: String = "SwiftgramBot"
    public var publicKey: String?
    public var iaps: [String] = []
    // MARK: Swiftgram
    /// Build flavour flag: authenticate new accounts against Telegram's test
    /// datacenters. Set from `sg_config` at build time; the in-app setting can
    /// turn it on for a normal build too.
    public var useTestServer: Bool = false

    public init() {
    }

    // MARK: Swiftgram
    // The synthesized decoder throws on any missing key, which would make a
    // partial sg_config fall back to defaults wholesale and silently drop the
    // keys that *were* provided. Decode each key independently instead.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = SGConfig()
        self.apiUrl = ((try? container.decodeIfPresent(String.self, forKey: .apiUrl)) ?? nil) ?? fallback.apiUrl
        self.webappUrl = ((try? container.decodeIfPresent(String.self, forKey: .webappUrl)) ?? nil) ?? fallback.webappUrl
        self.botUsername = ((try? container.decodeIfPresent(String.self, forKey: .botUsername)) ?? nil) ?? fallback.botUsername
        self.publicKey = (try? container.decodeIfPresent(String.self, forKey: .publicKey)) ?? nil
        self.iaps = ((try? container.decodeIfPresent([String].self, forKey: .iaps)) ?? nil) ?? fallback.iaps
        self.useTestServer = ((try? container.decodeIfPresent(Bool.self, forKey: .useTestServer)) ?? nil) ?? fallback.useTestServer
    }
}

private func parseSGConfig(_ jsonString: String) -> SGConfig {
    let jsonData = Data(jsonString.utf8)
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return (try? decoder.decode(SGConfig.self, from: jsonData)) ?? SGConfig()
}

private let baseAppBundleId = Bundle.main.bundleIdentifier!
private let buildConfig = BuildConfig(baseAppBundleId: baseAppBundleId)
public let SG_CONFIG: SGConfig = parseSGConfig(buildConfig.sgConfig)
public let SG_API_WEBAPP_URL_PARSED = URL(string: SG_CONFIG.webappUrl)!
