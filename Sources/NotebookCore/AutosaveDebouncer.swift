import Foundation

public final class AutosaveDebouncer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "notebook.autosave")
    private var pending: DispatchWorkItem?

    public init() {}

    public func schedule(after delay: TimeInterval, _ action: @escaping @Sendable () -> Void) {
        queue.sync {
            pending?.cancel()
            let job = DispatchWorkItem(block: action)
            pending = job
            queue.asyncAfter(deadline: .now() + delay, execute: job)
        }
    }

    public func cancel() {
        queue.sync {
            pending?.cancel()
            pending = nil
        }
    }
}
