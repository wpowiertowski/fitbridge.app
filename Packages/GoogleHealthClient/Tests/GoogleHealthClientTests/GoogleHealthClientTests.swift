import Testing
@testable import GoogleHealthClient

@Test func moduleNamePlaceholder() async throws {
    #expect(GoogleHealthClientPlaceholder.moduleName == "GoogleHealthClient")
    #expect(GoogleHealthClientPlaceholder.dependsOn == ["CoreModel", "Secrets"])
}
