import CheersCore
import Foundation
import Observation

@Observable
final class DictionaryStore {
    var entries: [DictionaryEntry] {
        didSet {
            guard entries != oldValue else { return }
            save()
            onChange?(entries)
        }
    }

    @ObservationIgnored var onChange: (([DictionaryEntry]) -> Void)?

    private let fileURL: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        fileURL = support.appending(path: "Cheers/dictionary.json")
        entries = (try? JSONDecoder().decode([DictionaryEntry].self, from: Data(contentsOf: fileURL))) ?? []
    }

    func add(term: String, soundsLike: String) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        entries.append(DictionaryEntry(term: trimmed, soundsLike: Self.parseAliases(soundsLike)))
    }

    func remove(_ ids: Set<DictionaryEntry.ID>) {
        entries.removeAll { ids.contains($0.id) }
    }

    static func parseAliases(_ text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(entries).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Cheers: failed to save dictionary: \(error)")
        }
    }
}
