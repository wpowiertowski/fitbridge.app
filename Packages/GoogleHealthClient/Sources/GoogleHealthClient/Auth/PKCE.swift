// PKCE.swift
//
// WP-04 step 1 (implementation-plan.md): RFC 7636 Proof Key for Code
// Exchange. `code_verifier` is a high-entropy random string (43-128 chars,
// unreserved character set); `code_challenge` is its S256 (SHA-256, base64url,
// unpadded) transform. Pure functions, no actor/network involvement, so they
// are fully testable on macOS against the RFC's own worked example
// (Appendix B).

import CryptoKit
import Foundation
import Security

nonisolated public enum PKCE {
    /// Generates a cryptographically random `code_verifier`.
    ///
    /// `byteCount` random bytes base64url-encode to `ceil(byteCount * 4 / 3)`
    /// characters with no padding; the default (32 bytes -> 43 chars) sits at
    /// RFC 7636's minimum length using the full entropy of a SHA-256-sized
    /// block. Every character produced by base64url encoding
    /// (`[A-Za-z0-9\-_]`) is already in RFC 7636's "unreserved" set, so no
    /// further filtering is needed.
    public static func generateCodeVerifier(byteCount: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = bytes.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, byteCount, buffer.baseAddress!)
        }
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed with status \(status)")
        return base64URLEncode(Data(bytes))
    }

    /// Generates an opaque random `state` parameter (CSRF protection on the
    /// authorization redirect). Same encoding as the verifier; a distinct
    /// name only for call-site clarity.
    public static func generateState(byteCount: Int = 16) -> String {
        generateCodeVerifier(byteCount: byteCount)
    }

    /// `code_challenge = BASE64URL-ENCODE(SHA256(ASCII(code_verifier)))`
    /// (RFC 7636 §4.2, transform "S256"). HealthLoom only ever uses S256 (the
    /// spec permits a "plain" method too, but every OAuth provider worth
    /// using -- Google included -- requires S256).
    public static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return base64URLEncode(Data(digest))
    }

    /// RFC 4648 §5 base64url, no padding (RFC 7636 §4.2's `BASE64URL-ENCODE`).
    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
