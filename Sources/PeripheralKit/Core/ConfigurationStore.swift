import Foundation

protocol RuleStore {
    func load() throws -> AppConfiguration
    func save(_ configuration: AppConfiguration) throws
}

struct ConfigurationStore: RuleStore {
    let directory: URL
    let legacyURL: URL
    var url: URL { directory.appendingPathComponent("settings.json") }

    init(directory: URL? = nil, legacyURL: URL? = nil) {
        let support = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        self.directory = directory ?? support.appendingPathComponent("PeripheralKit")
        self.legacyURL = legacyURL ?? support.appendingPathComponent("MKSleepRGB/config.json")
    }

    func load() throws -> AppConfiguration {
        if FileManager.default.fileExists(atPath: url.path) {
            let config = try JSONDecoder().decode(AppConfiguration.self, from: Data(contentsOf: url))
            try config.validate()
            return config
        }
        var config = AppConfiguration()
        if FileManager.default.fileExists(atPath: legacyURL.path) {
            config.rgb = try Configuration.load(from: legacyURL.path)
        }
        try config.validate()
        return config
    }

    func save(_ configuration: AppConfiguration) throws {
        try configuration.validate()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(configuration).write(to: url, options: .atomic)
    }
}
