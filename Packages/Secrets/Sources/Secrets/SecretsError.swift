// SecretsError.swift
//
// WP-03 (implementation-plan.md) / architecture.md D11 (privacy posture):
// errors from this package carry only Keychain status codes, never secret
// material. It is always safe to pass a `SecretsError` to a logger, an
// analytics event, or a crash report.

import Security

/// Error surface for `Secrets`.
///
/// Every case wraps an `OSStatus` from the Security framework — nothing
/// else. In particular, `description` renders only the OS-provided, generic
/// status message (e.g. "The specified item could not be found in the
/// keychain."), never a key name or a stored value.
public enum SecretsError: Error, Sendable, Equatable, CustomStringConvertible {
    /// A Keychain / Security-framework call returned a non-success,
    /// non-"not found" `OSStatus`.
    case keychain(status: OSStatus)

    /// The stored bytes for a key could not be decoded as UTF-8 text.
    /// Carries no bytes, only the fact that decoding failed.
    case undecodableValue

    public var description: String {
        switch self {
        case .keychain(let status):
            let message = (SecCopyErrorMessageString(status, nil) as String?) ?? "unknown error"
            return "SecretsError.keychain(status: \(status), \(message))"
        case .undecodableValue:
            return "SecretsError.undecodableValue"
        }
    }
}
