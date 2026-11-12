import Foundation

enum AppInfo {
    static var version: String {
        string(for: "CFBundleShortVersionString", in: .main) ?? "0.0.0"
    }

    static var build: String {
        string(for: "CFBundleVersion", in: .main) ?? "0"
    }

    static func string(for key: String, in bundle: Bundle) -> String? {
        bundle.object(forInfoDictionaryKey: key) as? String
    }
}
