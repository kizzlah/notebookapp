import XCTest
@testable import NotebookCoreTests

fileprivate extension NotebookCoreTests {
    @available(*, deprecated, message: "Not actually deprecated. Marked as deprecated to allow inclusion of deprecated tests (which test deprecated functionality) without warnings")
    static nonisolated(unsafe) let __allTests__NotebookCoreTests = [
        ("testHierarchyCreation", asyncTest(testHierarchyCreation)),
        ("testTrashPurgeAfter90Days", asyncTest(testTrashPurgeAfter90Days))
    ]
}
@available(*, deprecated, message: "Not actually deprecated. Marked as deprecated to allow inclusion of deprecated tests (which test deprecated functionality) without warnings")
func __NotebookCoreTests__allTests() -> [XCTestCaseEntry] {
    return [
        testCase(NotebookCoreTests.__allTests__NotebookCoreTests)
    ]
}