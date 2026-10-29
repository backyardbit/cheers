import Foundation

public struct TranscriptPostProcessor: Sendable {
    public var dictionary: [DictionaryEntry]
    public var removeFillers: Bool

    public init(dictionary: [DictionaryEntry] = [], removeFillers: Bool = true) {
        self.dictionary = dictionary
        self.removeFillers = removeFillers
    }

    public func process(_ text: String) -> String {
        finalize(clean(text))
    }

    public func clean(_ text: String) -> String {
        guard removeFillers else { return Self.tidyingWhitespace(text) }
        return Self.tidyingWhitespace(Self.collapsingRepeats(in: Self.removingFillers(from: text)))
    }

    public func finalize(_ text: String) -> String {
        Self.tidyingWhitespace(Self.applying(dictionary: dictionary, to: text))
    }

    static let repeatPattern = try? NSRegularExpression(
        pattern: #"(?<![\p{L}\p{N}'])(?!(?:had|that)(?![\p{L}\p{N}']))(\p{L}+)(?:[ \t]*,?[ \t]+\1(?![\p{L}\p{N}']))+"#,
        options: [.caseInsensitive]
    )

    public static func collapsingRepeats(in text: String) -> String {
        guard let repeatPattern else { return text }
        return repeatPattern.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: "$1"
        )
    }

    static let fillerPattern = try? NSRegularExpression(
        pattern: #"(?<![\p{L}\p{N}'])(?:u+m+|u+h+m*|e+r+m+|h+m+)(?![\p{L}\p{N}'])[,.…]*\s*"#,
        options: [.caseInsensitive]
    )

    public static func removingFillers(from text: String) -> String {
        guard let fillerPattern else { return text }
        var result = text
        let matches = fillerPattern.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches.reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            let atSentenceStart = isSentenceStart(result, before: range.lowerBound)
            result.replaceSubrange(range, with: "")
            if atSentenceStart {
                capitalizeFirstLetter(in: &result, from: range.lowerBound)
            }
        }
        return result
    }

    public static func applying(dictionary: [DictionaryEntry], to text: String) -> String {
        var rules: [(phrase: String, replacement: String)] = []
        for entry in dictionary {
            let term = entry.term.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !term.isEmpty else { continue }
            for alias in entry.soundsLike {
                let phrase = alias.trimmingCharacters(in: .whitespacesAndNewlines)
                if !phrase.isEmpty { rules.append((phrase, term)) }
            }
            rules.append((term, term))
        }
        rules.sort { $0.phrase.count > $1.phrase.count }

        var result = text
        for rule in rules {
            guard let regex = phraseRegex(rule.phrase) else { continue }
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: NSRegularExpression.escapedTemplate(for: rule.replacement)
            )
        }
        return result
    }

    static func phraseRegex(_ phrase: String) -> NSRegularExpression? {
        let words =
            phrase
            .components(separatedBy: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "-")))
            .filter { !$0.isEmpty }
            .map(NSRegularExpression.escapedPattern(for:))
        guard !words.isEmpty else { return nil }
        let body = words.joined(separator: #"[\s\-]+"#)
        return try? NSRegularExpression(
            pattern: #"(?<![\p{L}\p{N}])"# + body + #"(?![\p{L}\p{N}])"#,
            options: [.caseInsensitive]
        )
    }

    public static func tidyingWhitespace(_ text: String) -> String {
        var result = text.replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: #" +([,.!?;:])"#, with: "$1", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isSentenceStart(_ text: String, before index: String.Index) -> Bool {
        let preceding = text[..<index].last { !$0.isWhitespace }
        guard let preceding else { return true }
        return ".!?\n".contains(preceding)
    }

    private static func capitalizeFirstLetter(in text: inout String, from index: String.Index) {
        guard let letterIndex = text[index...].firstIndex(where: { $0.isLetter }) else { return }
        let letter = text[letterIndex]
        guard letter.isLowercase else { return }
        text.replaceSubrange(letterIndex...letterIndex, with: letter.uppercased())
    }
}
