import Foundation

public actor NotebookEngine {
    private let persistence: PersistenceCoordinator
    private(set) var state: NotebookState

    public init(persistence: PersistenceCoordinator = PersistenceCoordinator(), settings: NotebookSettings = NotebookSettings()) {
        self.persistence = persistence
        self.state = (try? persistence.load(settings: settings)) ?? NotebookState(notebooks: [PersistenceCoordinator.defaultRootNotebook], settings: settings)
    }


    public func currentSettings() -> NotebookSettings {
        state.settings
    }

    public func allNotebooks() -> [NotebookDocument] {
        state.notebooks.sorted(by: { $0.updatedAt > $1.updatedAt })
    }

    public func notebook(id: UUID) -> NotebookDocument? {
        state.notebooks.first(where: { $0.id == id })
    }

    public func addNotebook(title: String, color: NotebookTagColor, parentID: UUID?) -> NotebookDocument {
        let created = NotebookDocument(title: title, color: color, parentID: parentID)
        state.notebooks.append(created)
        if let parentID,
           let parentIndex = state.notebooks.firstIndex(where: { $0.id == parentID }) {
            state.notebooks[parentIndex].childIDs.append(created.id)
            state.notebooks[parentIndex].updatedAt = Date()
        }
        return created
    }

    public func updateNotebook(_ notebook: NotebookDocument) {
        guard let index = state.notebooks.firstIndex(where: { $0.id == notebook.id }) else { return }
        var updated = notebook
        updated.updatedAt = Date()
        state.notebooks[index] = updated
    }

    public func softDeleteNotebook(id: UUID) {
        guard let index = state.notebooks.firstIndex(where: { $0.id == id }) else { return }
        state.notebooks[index].deletedAt = Date()
        state.notebooks[index].updatedAt = Date()
    }

    public func purgeExpiredTrash(now: Date = Date()) {
        let expiryWindow = TimeInterval(state.settings.autoTrashPurgeDays * 24 * 60 * 60)
        state.notebooks.removeAll {
            guard let deletedAt = $0.deletedAt else { return false }
            return now.timeIntervalSince(deletedAt) >= expiryWindow
        }
    }

    public func save() throws {
        try persistence.save(state)
    }

    public func updateSettings(_ settings: NotebookSettings) {
        state.settings = settings
    }

    public func tableOfContents(for notebookID: UUID) -> [String] {
        guard let notebook = state.notebooks.first(where: { $0.id == notebookID }) else { return [] }

        let lines: [String]
        if notebook.mode == .markdown {
            lines = notebook.markdownText.components(separatedBy: .newlines)
        } else if let body = String(data: notebook.rtfData, encoding: .utf8) {
            lines = body.components(separatedBy: .newlines)
        } else {
            lines = []
        }

        return lines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("#") || $0.hasPrefix("##") || $0.hasPrefix("###") }
            .map { $0.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces) }
    }

    public func notebookTree() -> [NotebookNode] {
        let byID = Dictionary(uniqueKeysWithValues: state.notebooks.map { ($0.id, $0) })
        let roots = state.notebooks.filter { $0.parentID == nil && !$0.isDeleted }

        func makeNode(_ notebook: NotebookDocument) -> NotebookNode {
            let children = notebook.childIDs.compactMap { childID -> NotebookNode? in
                guard let child = byID[childID], !child.isDeleted else { return nil }
                return makeNode(child)
            }
            return NotebookNode(notebook: notebook, children: children)
        }

        return roots.map(makeNode)
    }
}

public struct NotebookNode: Identifiable, Equatable, Sendable {
    public var id: UUID { notebook.id }
    public let notebook: NotebookDocument
    public let children: [NotebookNode]

    public init(notebook: NotebookDocument, children: [NotebookNode]) {
        self.notebook = notebook
        self.children = children
    }
}
