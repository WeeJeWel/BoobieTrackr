import SwiftUI
import UIKit

struct BabyEditor: View {
    @EnvironmentObject private var store: FeedingStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var journal: FeedingJournal
    @State private var name: String
    @State private var confirmingDelete = false
    @State private var errorMessage: String?
    @State private var contentHeight: CGFloat = 230
    @FocusState private var nameFocused: Bool

    init(journal: FeedingJournal) {
        self.journal = journal
        _name = State(initialValue: journal.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Baby name").font(.subheadline).foregroundStyle(Palette.muted)
                TextField("Baby name", text: $name)
                    .font(.headline)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($nameFocused)
                    .onSubmit { nameFocused = false }
                    .onChange(of: name) { _, value in
                        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !journal.isDeleted, !trimmed.isEmpty, trimmed != journal.name else { return }
                        do {
                            try store.renameBaby(journal, name: trimmed)
                            errorMessage = nil
                        } catch { errorMessage = error.localizedDescription }
                    }
            }
            .padding(18)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18))
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Enter a baby name. The previous name is still saved.")
                    .font(.caption).foregroundStyle(Palette.muted)
            }
            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(Palette.accent)
            }
            Button("Delete Baby", role: .destructive) {
                nameFocused = false
                confirmingDelete = true
            }
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(.horizontal, 20).padding(.top, 28).padding(.bottom, 12)
        .foregroundStyle(Palette.cream)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = ceil($0) }
        .presentationDetents([.height(contentHeight)])
        .presentationBackground(Palette.background)
        .presentationDragIndicator(.visible)
        .alert("Delete Baby?", isPresented: $confirmingDelete) {
            Button("Delete Baby", role: .destructive) {
                do {
                    try store.deleteBaby(journal)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    dismiss()
                } catch { errorMessage = error.localizedDescription }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes \(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? journal.name : name) and all their feedings, including for anyone sharing this baby’s journal.")
        }
        .onChange(of: journal.isDeleted) { _, deleted in if deleted { dismiss() } }
    }
}
