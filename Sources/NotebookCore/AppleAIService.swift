import Foundation

public protocol AppleAIService {
    func summarize(text: String) async throws -> String
}

public struct FallbackAppleAIService: AppleAIService {
    public init() {}

    public func summarize(text: String) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "No content to summarize." }

        let preview = String(trimmed.prefix(220))
        return "AI preview: \(preview)\(trimmed.count > preview.count ? "…" : "")"
    }
}
