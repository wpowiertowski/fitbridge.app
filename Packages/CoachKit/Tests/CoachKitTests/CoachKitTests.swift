import Testing
@testable import CoachKit

@Test func moduleNamePlaceholder() async throws {
    #expect(CoachKitPlaceholder.moduleName == "CoachKit")
    #expect(CoachKitPlaceholder.dependsOn == ["CoreModel", "Secrets"])
}
