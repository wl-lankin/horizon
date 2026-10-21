// Ed25519 signing for update zips, matching Updater.swift.
//   swift scripts/sign_update.swift --generate <keyfile>   writes a new private key, prints the public key
//   swift scripts/sign_update.swift <file>                 prints the base64 signature
// The private key (base64, raw 32 bytes) comes from $HORIZON_UPDATE_KEY or ~/.horizon/update.key.
import CryptoKit
import Foundation

let args = Array(CommandLine.arguments.dropFirst())

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

if args.first == "--generate" {
    guard args.count == 2 else { fail("usage: --generate <keyfile>") }
    let path = args[1]
    if FileManager.default.fileExists(atPath: path) { fail("\(path) exists, refusing to overwrite") }
    let key = Curve25519.Signing.PrivateKey()
    FileManager.default.createFile(atPath: path, contents: Data(key.rawRepresentation.base64EncodedString().utf8),
                                   attributes: [.posixPermissions: 0o600])
    print(key.publicKey.rawRepresentation.base64EncodedString())
    exit(0)
}

guard args.count == 1 else { fail("usage: sign_update.swift <file>") }
let keyBase64 = ProcessInfo.processInfo.environment["HORIZON_UPDATE_KEY"]
    ?? (try? String(contentsOfFile: NSHomeDirectory() + "/.horizon/update.key", encoding: .utf8))
guard let keyBase64, let raw = Data(base64Encoded: keyBase64.trimmingCharacters(in: .whitespacesAndNewlines)),
      let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: raw) else { fail("no valid update key") }
guard let data = FileManager.default.contents(atPath: args[0]) else { fail("cannot read \(args[0])") }
print(try key.signature(for: data).base64EncodedString())
