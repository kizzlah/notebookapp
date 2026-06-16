import Foundation

public enum NotebookTagColor: String, Codable, CaseIterable, Sendable {
    case blue
    case green
    case orange
    case pink
    case purple

    public var hex: String {
        switch self {
        case .blue: "#4F81FF"
        case .green: "#3CB371"
        case .orange: "#FF9F1A"
        case .pink: "#E75480"
        case .purple: "#8A2BE2"
        }
    }
}

public enum EditorMode: String, Codable, CaseIterable, Sendable {
    case richText
    case markdown
}

public struct NotebookDocument: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var color: NotebookTagColor
    public var parentID: UUID?
    public var childIDs: [UUID]
    public var rtfData: Data
    public var markdownText: String
    public var mode: EditorMode
    public var attachments: [String]
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        color: NotebookTagColor = .blue,
        parentID: UUID? = nil,
        childIDs: [UUID] = [],
        rtfData: Data = Data(),
        markdownText: String = "",
        mode: EditorMode = .richText,
        attachments: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.color = color
        self.parentID = parentID
        self.childIDs = childIDs
        self.rtfData = rtfData
        self.markdownText = markdownText
        self.mode = mode
        self.attachments = attachments
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    public var isDeleted: Bool { deletedAt != nil }
}

public struct NotebookSettings: Codable, Equatable, Sendable {
    public var enableICloudSync: Bool
    public var showTableOfContents: Bool
    public var showMindGraph: Bool
    public var showDatabaseConfig: Bool
    public var showTerminal: Bool
    public var preferredColorScheme: String
    public var autosaveDebounceSeconds: TimeInterval
    public var autoTrashPurgeDays: Int
    public var useNerdFontWhenAvailable: Bool
    public var useAppleAI: Bool

    public init(
        enableICloudSync: Bool = false,
        showTableOfContents: Bool = true,
        showMindGraph: Bool = false,
        showDatabaseConfig: Bool = false,
        showTerminal: Bool = false,
        preferredColorScheme: String = "system",
        autosaveDebounceSeconds: TimeInterval = 1.25,
        autoTrashPurgeDays: Int = 90,
        useNerdFontWhenAvailable: Bool = true,
        useAppleAI: Bool = true
    ) {
        self.enableICloudSync = enableICloudSync
        self.showTableOfContents = showTableOfContents
        self.showMindGraph = showMindGraph
        self.showDatabaseConfig = showDatabaseConfig
        self.showTerminal = showTerminal
        self.preferredColorScheme = preferredColorScheme
        self.autosaveDebounceSeconds = autosaveDebounceSeconds
        self.autoTrashPurgeDays = autoTrashPurgeDays
        self.useNerdFontWhenAvailable = useNerdFontWhenAvailable
        self.useAppleAI = useAppleAI
    }
}

public struct NotebookState: Codable, Equatable, Sendable {
    public var notebooks: [NotebookDocument]
    public var settings: NotebookSettings

    public init(notebooks: [NotebookDocument] = [], settings: NotebookSettings = NotebookSettings()) {
        self.notebooks = notebooks
        self.settings = settings
    }
}
