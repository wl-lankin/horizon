import AppKit
import CryptoKit
import Security

/// Self-updater modelled on the Klecks/Tauri flow: reads latest.json from the newest GitHub release,
/// verifies the Ed25519 signature of the zip and the code signature of the new bundle, swaps the bundle
/// in place and lets the new version take over on the next start.
@MainActor
final class Updater: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case downloading(String)
        case ready(String)
        case failed(String)
    }

    struct Manifest: Decodable {
        let version: String
        let url: URL
        let signature: String
        let notes: String?
        let minimumSystemVersion: String?
    }

    static let shared = Updater()

    @Published private(set) var state: State = .idle

    let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    // The defaults override exists only to test updates against a local server.
    private let feed = UserDefaults.standard.string(forKey: "updateFeedURL").flatMap(URL.init(string:))
        ?? URL(string: "https://github.com/wl-lankin/horizon/releases/latest/download/latest.json")!
    private var timer: Timer?

    /// Only bundled builds update themselves; `swift run` and the snapshot mode never do.
    var isEnabled: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
            && Bundle.main.object(forInfoDictionaryKey: "HorizonUpdatePublicKey") != nil
            && !CommandLine.arguments.contains("--snapshot")
    }

    func start() {
        guard isEnabled, timer == nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { Task { await self.check(manual: false) } }
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { _ in
            Task { @MainActor in await Updater.shared.check(manual: false) }
        }
    }

    func check(manual: Bool) async {
        guard isEnabled else { return }
        switch state {
        case .checking, .downloading, .ready: return
        default: break
        }
        state = .checking
        do {
            var request = URLRequest(url: feed, cachePolicy: .reloadIgnoringLocalCacheData)
            request.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError("Keine Versionsinfo gefunden.") }
            let manifest = try JSONDecoder().decode(Manifest.self, from: data)

            guard Self.isNewer(manifest.version, than: currentVersion) else {
                state = manual ? .upToDate : .idle
                return
            }
            if let min = manifest.minimumSystemVersion, !Self.systemSupports(min) {
                throw UpdateError("Version \(manifest.version) braucht macOS \(min).")
            }
            state = .downloading(manifest.version)
            try await install(manifest)
            state = .ready(manifest.version)
        } catch {
            // Background checks stay quiet; only a manual check reports problems.
            state = manual ? .failed((error as? UpdateError)?.message ?? error.localizedDescription) : .idle
        }
    }

    func relaunch() {
        let path = Bundle.main.bundleURL.path
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", path]
        try? task.run()
        NSApp.terminate(nil)
    }

    // MARK: Install

    private func install(_ manifest: Manifest) async throws {
        let (zipURL, _) = try await URLSession.shared.download(from: manifest.url)
        let zipData = try Data(contentsOf: zipURL)

        guard let keyString = Bundle.main.object(forInfoDictionaryKey: "HorizonUpdatePublicKey") as? String,
              let keyData = Data(base64Encoded: keyString),
              let signature = Data(base64Encoded: manifest.signature),
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData),
              key.isValidSignature(signature, for: zipData) else {
            throw UpdateError("Die Signatur des Updates stimmt nicht.")
        }

        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("horizon-update-\(UUID().uuidString)")
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }

        try run("/usr/bin/ditto", ["-x", "-k", zipURL.path, work.path])
        let newApp = work.appendingPathComponent("Horizon.app")
        guard let newBundle = Bundle(url: newApp),
              newBundle.bundleIdentifier == Bundle.main.bundleIdentifier,
              (newBundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) == manifest.version else {
            throw UpdateError("Das Update enthält keine passende Horizon-App.")
        }
        try verifySameSigner(newApp)

        let current = Bundle.main.bundleURL
        let backup = work.appendingPathComponent("Horizon-old.app")
        try fm.moveItem(at: current, to: backup)
        do {
            try fm.moveItem(at: newApp, to: current)
        } catch {
            try? fm.moveItem(at: backup, to: current)
            throw UpdateError("Keine Schreibrechte für \(current.deletingLastPathComponent().path).")
        }
    }

    /// The new bundle must satisfy this app's own designated requirement, i.e. carry the same certificate.
    private func verifySameSigner(_ url: URL) throws {
        var selfCode: SecCode?
        var selfStatic: SecStaticCode?
        var requirement: SecRequirement?
        var newCode: SecStaticCode?
        guard SecCodeCopySelf([], &selfCode) == errSecSuccess, let selfCode,
              SecCodeCopyStaticCode(selfCode, [], &selfStatic) == errSecSuccess, let selfStatic,
              SecCodeCopyDesignatedRequirement(selfStatic, [], &requirement) == errSecSuccess,
              SecStaticCodeCreateWithPath(url as CFURL, [], &newCode) == errSecSuccess, let newCode,
              SecStaticCodeCheckValidity(newCode, SecCSFlags(rawValue: kSecCSCheckAllArchitectures), requirement) == errSecSuccess
        else {
            throw UpdateError("Das Update ist nicht mit dem Horizon-Zertifikat signiert.")
        }
    }

    private func run(_ tool: String, _ args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw UpdateError("Entpacken fehlgeschlagen.") }
    }

    // MARK: Versions

    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = numbers(a), pb = numbers(b)
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0, y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    private static func numbers(_ v: String) -> [Int] {
        v.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
            .split(separator: "-").first.map { $0.split(separator: ".").map { Int($0) ?? 0 } } ?? []
    }

    private static func systemSupports(_ minimum: String) -> Bool {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return !isNewer(minimum, than: "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)")
    }
}

struct UpdateError: Error {
    let message: String
    init(_ message: String) { self.message = message }
}
