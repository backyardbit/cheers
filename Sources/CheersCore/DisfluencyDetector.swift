import Foundation

public enum DisfluencyDetector {
    private static let cueWords: Set<String> = [
        "like", "actually", "basically", "literally", "sorry", "wait", "um", "uh", "uhm", "erm", "hmm",
    ]

    private static let cuePhrases = [
        "you know", "i mean", "sort of", "kind of", "no wait", "scratch that", "or rather", "let me rephrase",
        "what i meant", "gonna", "wanna",
    ]

    public static func needsCleanup(_ text: String) -> Bool {
        let lowered = text.lowercased()
        let words = tokens(lowered)
        if words.contains(where: cueWords.contains) {
            return true
        }
        let spaced = " " + words.joined(separator: " ") + " "
        if cuePhrases.contains(where: { spaced.contains(" \($0) ") }) {
            return true
        }
        return hasNearbyRepeat(words) || hasRestartedClause(lowered)
    }

    private static func tokens(_ text: String) -> [String] {
        text.split { !$0.isLetter && !$0.isNumber && $0 != "'" && $0 != "’" }.map(String.init)
    }

    private static func hasNearbyRepeat(_ words: [String]) -> Bool {
        for (index, word) in words.enumerated() where word.count > 1 || word == "i" {
            let window = words[(index + 1)..<min(index + 4, words.count)]
            if window.contains(word), !["had", "that", "very", "really"].contains(word) {
                return true
            }
        }
        return false
    }

    private static func hasRestartedClause(_ text: String) -> Bool {
        let clauses = text.split { ",.;!?—".contains($0) }.map { tokens(String($0)) }.filter { !$0.isEmpty }
        for (current, next) in zip(clauses, clauses.dropFirst())
        where current.count <= 5 && current.first == next.first {
            return true
        }
        return false
    }
}
