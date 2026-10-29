import Testing

@testable import CheersCore

struct DisfluencyDetectorTests {
    @Test(arguments: [
        "Send the report to Sarah by Friday.",
        "The deploy finished and every check passed.",
        "She had had enough of the meeting.",
        "Can you review my pull request before lunch?",
    ])
    func cleanSentencesSkipCleanup(_ text: String) {
        #expect(!DisfluencyDetector.needsCleanup(text))
    }

    @Test(arguments: [
        "It doesn't seem like filler words are getting removed.",
        "Let's meet at 5, no wait, 6 pm tomorrow.",
        "I was gonna, I wanted to ask about the review.",
        "We need to, we have to finish this today.",
        "I don't. I think that there's work to do.",
        "It's not it's definitely not ready yet.",
        "Could you, you know, look at it?",
        "The meeting is at three, sorry, four.",
    ])
    func disfluentSentencesNeedCleanup(_ text: String) {
        #expect(DisfluencyDetector.needsCleanup(text))
    }
}
