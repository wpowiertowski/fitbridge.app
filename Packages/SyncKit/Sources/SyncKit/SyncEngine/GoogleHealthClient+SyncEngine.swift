// GoogleHealthClient+SyncEngine.swift
//
// WP-09 (implementation-plan.md): conforms the real `GoogleHealthClient`
// (DataClient struct, GoogleHealthClient/DataClient/GoogleHealthDataClient.swift)
// to `GoogleReconcileClient` (SyncEngineTypes.swift) so `SyncEngine` can hold
// the narrow protocol instead of the concrete client. Not a retroactive
// conformance: SyncKit (this module) owns `GoogleReconcileClient`, even
// though it doesn't own `GoogleHealthClient` -- exactly the pattern WP-04/05
// already used for `Secrets.KeychainStore`'s `GoogleTokenStoring` conformance
// (`KeychainStore+GoogleTokenStoring.swift`, progress.md's WP-04/05 entry).
// No new methods needed: the real `reconcile(type:since:until:pageToken:)`'s
// signature already matches the protocol requirement exactly -- its default
// `pageToken: String? = nil` is simply not part of the protocol's required
// shape, which doesn't prevent conformance.

import GoogleHealthClient

extension GoogleHealthClient: GoogleReconcileClient {}
