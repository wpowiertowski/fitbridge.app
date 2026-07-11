// PKCETests.swift
//
// WP-04 required test: "PKCE challenge correctness (known verifier → known
// S256 challenge)."

import Testing
@testable import GoogleHealthClient

@Suite("PKCE")
struct PKCETests {
    @Test("known verifier produces the RFC 7636 Appendix B.1 test vector challenge")
    func knownVectorChallenge() {
        // RFC 7636 Appendix B: the spec's own worked example.
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        let expectedChallenge = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
        #expect(PKCE.codeChallenge(for: verifier) == expectedChallenge)
    }

    @Test("generated verifiers are within RFC 7636's 43-128 char range and use only the unreserved alphabet")
    func generatedVerifierShape() {
        let unreserved = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        // 32 bytes is PKCE.generateCodeVerifier's default and the minimum
        // byte count whose base64url encoding meets RFC 7636's 43-char
        // floor (ceil(32*4/3) == 43); smaller byte counts would produce an
        // out-of-spec verifier, which is a defect in a *caller* choosing a
        // byteCount, not something this shape test should exercise.
        for byteCount in [32, 48, 64, 96] {
            let verifier = PKCE.generateCodeVerifier(byteCount: byteCount)
            #expect(verifier.count >= 43)
            #expect(verifier.count <= 128)
            #expect(verifier.allSatisfy { unreserved.contains($0) })
        }
    }

    @Test("generated verifiers are not repeated across calls")
    func generatedVerifiersAreRandom() {
        let verifiers = (0..<20).map { _ in PKCE.generateCodeVerifier() }
        #expect(Set(verifiers).count == verifiers.count)
    }

    @Test("code challenge is deterministic for a given verifier")
    func challengeIsDeterministic() {
        let verifier = PKCE.generateCodeVerifier()
        #expect(PKCE.codeChallenge(for: verifier) == PKCE.codeChallenge(for: verifier))
    }
}
