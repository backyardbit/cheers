import Foundation

public struct DictionaryEntry: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var term: String
    public var soundsLike: [String]

    public init(id: UUID = UUID(), term: String, soundsLike: [String] = []) {
        self.id = id
        self.term = term
        self.soundsLike = soundsLike
    }

    public var isSpeakable: Bool {
        let trimmed = term.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3, trimmed.count <= 40 else { return false }
        return trimmed.allSatisfy { $0.isLetter || $0.isNumber || " -'.".contains($0) }
    }
}
