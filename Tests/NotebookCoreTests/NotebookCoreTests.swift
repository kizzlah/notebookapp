import XCTest
@testable import NotebookCore

final class NotebookCoreTests: XCTestCase {
    private func makeEngine(settings: NotebookSettings = .init()) -> NotebookEngine {
        let tempRoot = URL(filePath: NSTemporaryDirectory())
            .appendingPathComponent("notebookapp-tests-\(UUID().uuidString)", isDirectory: true)
        let persistence = PersistenceCoordinator(localRootOverride: tempRoot)
        return NotebookEngine(persistence: persistence, settings: settings)
    }

    func testHierarchyCreation() async throws {
        let engine = makeEngine()

        let root = await engine.addNotebook(title: "Root", color: .blue, parentID: nil)
        let child = await engine.addNotebook(title: "Child", color: .green, parentID: root.id)

        let tree = await engine.notebookTree()
        let rootNode = tree.first(where: { $0.id == root.id })
        XCTAssertEqual(rootNode?.children.first?.id, child.id)
    }

    func testTrashPurgeAfter90Days() async throws {
        var settings = NotebookSettings()
        settings.autoTrashPurgeDays = 90
        let engine = makeEngine(settings: settings)

        let created = await engine.addNotebook(title: "Trash Me", color: .orange, parentID: nil)
        await engine.softDeleteNotebook(id: created.id)

        guard var trashed = await engine.notebook(id: created.id) else {
            XCTFail("Expected notebook")
            return
        }

        trashed.deletedAt = Calendar.current.date(byAdding: .day, value: -91, to: Date())
        await engine.updateNotebook(trashed)

        await engine.purgeExpiredTrash(now: Date())

        let remaining = await engine.notebook(id: created.id)
        XCTAssertNil(remaining)
    }
}
