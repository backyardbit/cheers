import Testing

@testable import CheersCore

struct TranscriptPostProcessorTests {
    @Test func removesFillersAndRecapitalizes() {
        let processor = TranscriptPostProcessor()
        #expect(processor.process("Um, so I think, uh, we should ship it.") == "So I think, we should ship it.")
        #expect(processor.process("It works. Uhm, mostly.") == "It works. Mostly.")
    }

    @Test func collapsesRepeatedWords() {
        let processor = TranscriptPostProcessor()
        #expect(processor.process("So like like like it works.") == "So like it works.")
        #expect(processor.process("Send the the report, it is is ready.") == "Send the report, it is ready.")
        #expect(processor.process("I I, I think so.") == "I think so.")
    }

    @Test func keepsLegitimateDoubles() {
        let processor = TranscriptPostProcessor()
        #expect(processor.process("She had had enough.") == "She had had enough.")
        #expect(processor.process("I know that that works.") == "I know that that works.")
    }

    @Test func keepsWordsContainingFillerLetters() {
        let processor = TranscriptPostProcessor()
        #expect(processor.process("The umbrella is in the hummer.") == "The umbrella is in the hummer.")
    }

    @Test func dictionaryFixesCasingAndAliases() {
        let processor = TranscriptPostProcessor(dictionary: [
            DictionaryEntry(term: "macOS", soundsLike: ["mac os"]),
            DictionaryEntry(term: "Kubernetes", soundsLike: ["cooper netties"]),
        ])
        #expect(processor.process("I run Mac OS and macos.") == "I run macOS and macOS.")
        #expect(processor.process("Deploy it on cooper-netties.") == "Deploy it on Kubernetes.")
    }

    @Test func dictionaryExpandsPhrases() {
        let processor = TranscriptPostProcessor(dictionary: [
            DictionaryEntry(term: "jane@example.com", soundsLike: ["my email"])
        ])
        #expect(processor.process("Send it to my email, please.") == "Send it to jane@example.com, please.")
    }

    @Test func dictionaryRespectsWordBoundaries() {
        let processor = TranscriptPostProcessor(dictionary: [DictionaryEntry(term: "Rex")])
        #expect(processor.process("rex is not in prefix.") == "Rex is not in prefix.")
    }

    @Test func speakableTerms() {
        #expect(DictionaryEntry(term: "Kubernetes").isSpeakable)
        #expect(!DictionaryEntry(term: "jane@example.com").isSpeakable)
        #expect(!DictionaryEntry(term: "ab").isSpeakable)
    }
}
