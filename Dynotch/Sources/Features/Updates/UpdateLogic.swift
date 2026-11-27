import CryptoKit
import Foundation
import Security

/// A release published on GitHub (spec U-1).
struct ReleaseInfo: Equatable, Sendable {
    let version: String
    let archive: URL
    let checksums: URL?

    var archiveName: String { archive.lastPathComponent }
}

/// The parts of updating that need no network or disk (spec U-1…U-3).
enum UpdateLogic {
    static let latestRelease = URL(string: "https://api.github.com/repos/Kera77/Dynotch/releases/latest")
    /// The newest releases, test builds (prereleases) included, for the beta channel (spec U-7).
    static let recentReleases = URL(string: "https://api.github.com/repos/Kera77/Dynotch/releases?per_page=20")

    /// A test build: the last part of the version is not 0, e.g. "1.7.3" (spec U-6).
    static func isTestBuild(_ version: String) -> Bool {
        let parts = version.trimmingCharacters(in: CharacterSet(charactersIn: "vV ")).split(separator: ".")
        return parts.count >= 3 && (Int(parts[2]) ?? 0) != 0
    }

    /// "1.10.0" is newer than "1.9.3"; missing parts count as 0.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        func parts(_ version: String) -> [Int] {
            version.trimmingCharacters(in: CharacterSet(charactersIn: "vV ")).split(separator: ".").map { Int($0) ?? 0 }
        }
        let lhs = parts(candidate)
        let rhs = parts(current)
        for index in 0..<max(lhs.count, rhs.count) {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right { return left > right }
        }
        return false
    }

    /// The app's names, newest first: the new one, then the one before the rename (spec U-11).
    static let appNames = ["Wingmate", "Dynotch"]
    /// The bundle identifier the renamed app has (spec U-11).
    static let renamedIdentifier = "com.peterkereki.Wingmate"

    /// The app bundle in an unpacked release, under either name (spec U-11).
    static func appBundle(in names: [String]) -> String? {
        appNames.map { "\($0).app" }.first { names.contains($0) }
    }

    /// The running app's designated requirement with its identifier swapped for `identifier`:
    /// the same certificate, the other name (spec U-11). Nil if the requirement does not name
    /// `own` as its identifier.
    static func requirement(_ designated: String, own: String, swappedTo identifier: String) -> String? {
        let clause = "identifier \"\(own)\""
        guard designated.contains(clause) else { return nil }
        return designated.replacingOccurrences(of: clause, with: "identifier \"\(identifier)\"")
    }

    /// The release's version and its versioned zip, from GitHub's answer (a full release only).
    static func release(fromJSON data: Data) -> ReleaseInfo? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return release(from: object, allowingPrerelease: false)
    }

    /// The newest release in GitHub's release list, prereleases included (spec U-7).
    static func newestRelease(fromListJSON data: Data) -> ReleaseInfo? {
        guard let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        return list.compactMap { release(from: $0, allowingPrerelease: true) }
            .reduce(nil) { best, next in
                guard let best else { return next }
                return isNewer(next.version, than: best.version) ? next : best
            }
    }

    private static func release(from object: [String: Any], allowingPrerelease: Bool) -> ReleaseInfo? {
        guard let tag = object["tag_name"] as? String,
              object["draft"] as? Bool != true,
              allowingPrerelease || object["prerelease"] as? Bool != true,
              let assets = object["assets"] as? [[String: Any]]
        else { return nil }
        let version = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        func url(named name: String) -> URL? {
            assets.first { $0["name"] as? String == name }
                .flatMap { $0["browser_download_url"] as? String }
                .flatMap(URL.init(string:))
        }
        // The app is called Wingmate from 1.9.3 on; older releases still have the old name (spec U-11).
        guard let archive = appNames.lazy.compactMap({ url(named: "\($0)-\(version).zip") }).first else { return nil }
        return ReleaseInfo(version: version, archive: archive, checksums: url(named: "SHA256SUMS.txt"))
    }

    /// The hash listed for a file in SHA256SUMS.txt ("<hash>  ./name").
    static func expectedHash(forFile name: String, inChecksums text: String) -> String? {
        for line in text.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: " ", omittingEmptySubsequences: true)
            guard fields.count >= 2, let file = fields.last else { continue }
            let listed = file.hasPrefix("./") ? file.dropFirst(2) : file[...]
            if listed.trimmingCharacters(in: CharacterSet(charactersIn: "*")) == name { return String(fields[0]).lowercased() }
        }
        return nil
    }

    static func sha256(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Only an app in a normal place replaces itself: not a build run from Xcode, not a test host.
    static func canReplace(appAt path: String) -> Bool {
        path.hasSuffix(".app") && !path.contains("/DerivedData/") && !path.contains("/Build/Products/")
    }

    /// Waits for the running app to quit, puts the new bundle in place (putting the old one back if
    /// that fails) and opens it. Arguments: pid, new app, where it goes, folder to remove, the
    /// running app. When the app was renamed (spec U-11) the new bundle goes beside the old one,
    /// which is removed only once the new one is in place.
    static let installScript = """
    while /bin/kill -0 "$1" 2>/dev/null; do /bin/sleep 0.2; done
    app="$3"
    /bin/rm -rf "$3.previous"
    if [ -e "$3" ] && ! /bin/mv "$3" "$3.previous"; then
      app="$5"
    elif /usr/bin/ditto "$2" "$3"; then
      /bin/rm -rf "$3.previous"
      [ "$5" = "$3" ] || /bin/rm -rf "$5"
    else
      /bin/rm -rf "$3"
      [ ! -e "$3.previous" ] || /bin/mv "$3.previous" "$3"
      [ -e "$3" ] || app="$5"
    fi
    /usr/bin/xattr -dr com.apple.quarantine "$app" 2>/dev/null
    /usr/bin/open "$app"
    /bin/rm -rf "$4"
    """

    /// True if the app at `url` is signed by the same identity as the running app: it satisfies
    /// the running app's designated requirement (spec U-2), or the same requirement with the
    /// renamed app's identifier (spec U-11).
    static func isSignedLikeRunningApp(appAt url: URL) -> Bool {
        var running: SecCode?
        guard SecCodeCopySelf([], &running) == errSecSuccess, let running else { return false }
        var runningStatic: SecStaticCode?
        guard SecCodeCopyStaticCode(running, [], &runningStatic) == errSecSuccess, let runningStatic else { return false }
        var designated: SecRequirement?
        guard SecCodeCopyDesignatedRequirement(runningStatic, [], &designated) == errSecSuccess, let designated else { return false }
        var candidate: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &candidate) == errSecSuccess, let candidate else { return false }
        let flags = SecCSFlags(rawValue: kSecCSCheckNestedCode | kSecCSStrictValidate)
        if SecStaticCodeCheckValidity(candidate, flags, designated) == errSecSuccess { return true }
        var text: CFString?
        guard SecRequirementCopyString(designated, [], &text) == errSecSuccess, let text,
              let own = Bundle.main.bundleIdentifier, own != renamedIdentifier,
              let swapped = requirement(text as String, own: own, swappedTo: renamedIdentifier)
        else { return false }
        var other: SecRequirement?
        guard SecRequirementCreateWithString(swapped as CFString, [], &other) == errSecSuccess, let other else { return false }
        return SecStaticCodeCheckValidity(candidate, flags, other) == errSecSuccess
    }
}
