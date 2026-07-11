// DataSource.swift
//
// WP-05 step 2 (implementation-plan.md) / base-knowledge.md §2: "Everything
// nests under `<data_type>.<field>` + a `dataSource` wrapper (`platform`,
// `device.displayName`, `recordingMethod`)."

nonisolated public struct DataSource: Sendable, Hashable, Codable {
    public var platform: String?
    public var deviceDisplayName: String?
    public var recordingMethod: String?

    public init(platform: String?, deviceDisplayName: String?, recordingMethod: String?) {
        self.platform = platform
        self.deviceDisplayName = deviceDisplayName
        self.recordingMethod = recordingMethod
    }
}
