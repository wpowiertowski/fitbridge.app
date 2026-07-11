import Testing
@testable import SyncKit

@Test func moduleNamePlaceholder() async throws {
    #expect(SyncKitPlaceholder.moduleName == "SyncKit")
    #expect(SyncKitPlaceholder.dependsOn == ["CoreModel", "Secrets", "GoogleHealthClient"])
}
