import Foundation

/// One pairing code: `<id>.<secret>`. The kernel opens it with
/// `python -m kernel shell pair --name phone` and it works once, for five minutes.
public struct PairingCode: Hashable, Sendable {
    public let id: String
    public let secret: String

    public var text: String { "\(id).\(secret)" }

    /// Reads a typed or pasted code. The id is 8 hex letters; the secret is
    /// URL-safe base64. The kernel is the real check; this only stops typos early.
    public init?(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let id = parts[0].lowercased()
        let secret = String(parts[1])
        guard id.count == 8, id.allSatisfy(\.isHexDigit) else { return nil }
        guard (16...128).contains(secret.count),
              secret.unicodeScalars.allSatisfy(PairingCode.secretCharacters.contains)
        else { return nil }
        self.id = id
        self.secret = secret
    }

    static let secretCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
    )
}

/// What the person pasted on the pairing screen: a code, and the kernel
/// address when they pasted the whole link.
public struct PairingInput: Hashable, Sendable {
    public let code: PairingCode
    public let kernel: URL?

    public init(code: PairingCode, kernel: URL?) {
        self.code = code
        self.kernel = kernel
    }

    /// Reads `https://<host>/pair.html#<id>.<secret>`, the path form
    /// `/pair.html#<id>.<secret>`, or the bare code.
    public static func parse(_ raw: String) -> PairingInput? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // A link pasted from a chat may come in angle brackets or quotes.
        for (open, close) in [("<", ">"), ("\"", "\""), ("'", "'")] where text.hasPrefix(open) && text.hasSuffix(close) && text.count >= 2 {
            text = String(text.dropFirst().dropLast())
        }
        guard !text.isEmpty else { return nil }

        guard let hash = text.firstIndex(of: "#") else {
            // No fragment: a bare code, or nothing we read.
            guard let code = PairingCode(text) else { return nil }
            return PairingInput(code: code, kernel: nil)
        }
        let before = String(text[..<hash])
        let fragment = String(text[text.index(after: hash)...])
        guard let code = PairingCode(fragment) else { return nil }

        guard before.hasSuffix("pair.html") else { return nil }
        let base = String(before.dropLast("pair.html".count))
        if base == "/" || base.isEmpty {
            return PairingInput(code: code, kernel: nil)
        }
        guard let kernel = KernelAddress.parse(base, requireScheme: true) else { return nil }
        return PairingInput(code: code, kernel: kernel)
    }
}

/// The address the app reaches the kernel's shell on, always HTTPS.
public enum KernelAddress {
    /// Reads `https://box.example.ts.net`, with or without a port, a path
    /// prefix, or a trailing slash. A bare host name gets `https://`.
    /// Plain HTTP, user names, queries, and fragments are refused.
    public static func parse(_ raw: String, requireScheme: Bool = false) -> URL? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains(where: \.isWhitespace) else { return nil }
        if !text.contains("://") {
            if requireScheme { return nil }
            text = "https://" + text
        }
        guard var parts = URLComponents(string: text),
              parts.scheme?.lowercased() == "https",
              let host = parts.host, !host.isEmpty,
              parts.user == nil, parts.password == nil,
              parts.query == nil, parts.fragment == nil
        else { return nil }
        parts.scheme = "https"
        parts.host = host.lowercased()
        while parts.path.hasSuffix("/") {
            parts.path.removeLast()
        }
        return parts.url
    }
}
