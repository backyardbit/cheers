import CheersCore
import SwiftUI

struct DictionarySettingsView: View {
    @Bindable var store: DictionaryStore

    @State private var newTerm = ""
    @State private var newAliases = ""
    @State private var selection: Set<DictionaryEntry.ID> = []
    @FocusState private var termFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(
                """
                Names, jargon and spellings Cheers should always get right. Add what it mishears as \
                “sounds like” to correct it, or to expand a phrase like “my email”.
                """
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Table($store.entries, selection: $selection) {
                TableColumn("Word") { $entry in
                    TextField("Word", text: $entry.term)
                        .textFieldStyle(.plain)
                }
                TableColumn("Sounds like") { $entry in
                    TextField("comma separated", text: aliasBinding($entry))
                        .textFieldStyle(.plain)
                }
            }
            .onDeleteCommand { store.remove(selection) }
            .overlay {
                if store.entries.isEmpty {
                    ContentUnavailableView(
                        "No words yet",
                        systemImage: "character.book.closed",
                        description: Text("Add a word below.")
                    )
                }
            }

            HStack {
                TextField("Word", text: $newTerm)
                    .focused($termFocused)
                    .onSubmit(add)
                TextField("Sounds like (optional)", text: $newAliases)
                    .onSubmit(add)
                Button("Add", action: add)
                    .disabled(newTerm.trimmingCharacters(in: .whitespaces).isEmpty)
                Button {
                    store.remove(selection)
                    selection.removeAll()
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(selection.isEmpty)
            }
        }
        .padding(20)
    }

    private func add() {
        store.add(term: newTerm, soundsLike: newAliases)
        newTerm = ""
        newAliases = ""
        termFocused = true
    }

    private func aliasBinding(_ entry: Binding<DictionaryEntry>) -> Binding<String> {
        Binding(
            get: { entry.wrappedValue.soundsLike.joined(separator: ", ") },
            set: { entry.wrappedValue.soundsLike = DictionaryStore.parseAliases($0) }
        )
    }
}
