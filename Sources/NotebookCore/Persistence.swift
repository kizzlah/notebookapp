import Foundation

public enum PersistenceError: Error {
    case unresolvedStorageURL
}

public struct PersistenceCoordinator: Sendable {
    public static let fileName = "NotebookState.json"
    private let localRootOverride: URL?

    public init(localRootOverride: URL? = nil) {
        self.localRootOverride = localRootOverride
    }

    public func load(settings: NotebookSettings) throws -> NotebookState {
        let url = try storageURL(settings: settings)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return NotebookState(notebooks: [Self.defaultRootNotebook], settings: settings)
        }

        let data = try Data(contentsOf: url)
        var state = try JSONDecoder().decode(NotebookState.self, from: data)
        state.settings = settings
        return state
    }

    public func save(_ state: NotebookState) throws {
        let url = try storageURL(settings: state.settings)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(state)
        try data.write(to: url, options: .atomic)
    }

    public func storageURL(settings: NotebookSettings) throws -> URL {
        if settings.enableICloudSync,
           let cloudURL = cloudContainerURL()?.appendingPathComponent(Self.fileName) {
            return cloudURL
        }

        if let localRootOverride {
            return localRootOverride
                .appendingPathComponent("NotebookApp", isDirectory: true)
                .appendingPathComponent(Self.fileName)
        }

        let localRoot = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let localRoot else { throw PersistenceError.unresolvedStorageURL }
        return localRoot
            .appendingPathComponent("NotebookApp", isDirectory: true)
            .appendingPathComponent(Self.fileName)
    }

    private func cloudContainerURL() -> URL? {
        #if os(macOS) || os(iOS)
        guard FileManager.default.ubiquityIdentityToken != nil else { return nil }
        return FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("NotebookApp", isDirectory: true)
        #else
        return nil
        #endif
    }

    public static var defaultRootNotebook: NotebookDocument {
        NotebookDocument(title: "Primary Notebook", color: .blue)
    }
}
