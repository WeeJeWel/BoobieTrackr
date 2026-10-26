import CloudKit
import CoreData
import SwiftUI
import UIKit

extension FeedingStore {
    func acceptShare(_ metadata: CKShare.Metadata) {
        guard let sharedStore else {
            errorMessage = "Shared iCloud storage isn’t available yet. Please try the invitation again."
            return
        }
        container.acceptShareInvitations(from: [metadata], into: sharedStore) { _, error in
            Task { @MainActor in
                if let error { self.errorMessage = error.localizedDescription }
                else {
                    self.selectedJournalID = ""
                    self.cloudStatus = "Invitation accepted. Syncing your shared journal…"
                    self.refresh()
                }
            }
        }
    }
}

struct SharingView: View {
    @EnvironmentObject private var store: FeedingStore
    @Environment(\.dismiss) private var dismiss
    @State private var share: CKShare?
    @State private var preparing = false
    @State private var showingShare = false
    @State private var message: String?
    @State private var loadID = UUID()

    private var isSharedJournal: Bool {
        store.sharedStore != nil && store.activeJournal?.objectID.persistentStore == store.sharedStore
    }

    var body: some View {
        Group {
            if isSharedJournal {
                if let share {
                    CloudSharingSheet(share: share, babyName: store.activeJournal?.name ?? "Our baby")
                        .environmentObject(store)
                } else {
                    NavigationStack {
                        VStack(spacing: 16) {
                            if let message {
                                Text(message).multilineTextAlignment(.center)
                                    .foregroundStyle(Palette.muted)
                                Button("Try Again") { loadID = UUID() }
                                    .tint(Palette.accent)
                            } else {
                                ProgressView("Loading participants…")
                            }
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Palette.background)
                        .navigationTitle("Participants")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                    }
                }
            } else {
                invitationView
            }
        }
        .task(id: loadID) {
            guard isSharedJournal, let journal = store.activeJournal else { return }
            message = nil
            do {
                // Participants open the existing share; never create a new share
                // for a journal that belongs to someone else.
                if let existing = try store.container.fetchShares(matching: [journal.objectID])[journal.objectID] {
                    share = existing
                } else {
                    message = "Sharing details are still syncing. Please try again."
                }
            } catch { message = error.localizedDescription }
        }
        .preferredColorScheme(.dark)
    }

    private var invitationView: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "person.2.fill").font(.title).foregroundStyle(Palette.accent)
                        Text(store.activeJournal?.name ?? "Our baby").font(.system(.title2, design: .serif))
                        Text("Invite your partner to this baby’s journal. Everyone invited can rename the baby and add, edit, or delete feedings.")
                            .font(.subheadline).foregroundStyle(Palette.muted)
                    }.padding(.vertical, 12)
                    Button {
                        preparing = true
                        Task { @MainActor in
                            do {
                                guard !store.localOnly else {
                                    message = "Sharing needs a signed build with iCloud enabled. Demo data stays on this device."
                                    preparing = false
                                    return
                                }
                                let journal = try store.journalForNewEvent()
                                let journalTitle = "\(journal.name)’s feeding journal"
                                try store.container.viewContext.save()
                                store.refresh()
                                if let existing = try store.container.fetchShares(matching: [journal.objectID])[journal.objectID] {
                                    share = existing
                                } else {
                                    share = try await withCheckedThrowingContinuation { continuation in
                                        store.container.share([journal], to: nil) { _, share, _, error in
                                            if let error { continuation.resume(throwing: error) }
                                            else if let share {
                                                share[CKShare.SystemFieldKey.title] = journalTitle as CKRecordValue
                                                continuation.resume(returning: share)
                                            } else { continuation.resume(throwing: FeedingError.storageUnavailable) }
                                        }
                                    }
                                }
                                showingShare = true
                            } catch { message = error.localizedDescription }
                            preparing = false
                        }
                    } label: {
                        HStack {
                            Label("Invite Partner", systemImage: "person.badge.plus")
                            Spacer()
                            if preparing { ProgressView() }
                        }
                    }
                    .disabled(preparing)
                }
                .listRowBackground(Palette.surface)

                Section("Storage") {
                    Label(store.cloudStatus, systemImage: "icloud")
                        .font(.subheadline).foregroundStyle(Palette.muted)
                    Text("Feedings are saved on your device immediately and sync through iCloud when connected. Accept your partner’s invitation on your iPhone; the shared journal also syncs to your Watch.")
                        .font(.footnote).foregroundStyle(Palette.muted)
                }
                .listRowBackground(Palette.surface)
            }
            .scrollContentBackground(.hidden).background(Palette.background)
            .navigationTitle("Invite Partner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showingShare) {
                if let share { CloudSharingSheet(share: share, babyName: store.activeJournal?.name ?? "Our baby").environmentObject(store) }
            }
            .alert("iCloud sharing", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            } message: { Text(message ?? "") }
        }
        .preferredColorScheme(.dark)
    }
}

struct CloudSharingSheet: UIViewControllerRepresentable {
    @EnvironmentObject private var store: FeedingStore
    let share: CKShare
    let babyName: String

    func makeCoordinator() -> Coordinator { Coordinator(store: store, babyName: babyName) }
    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: CKContainer(identifier: FeedingStore.containerID))
        controller.availablePermissions = [.allowPrivate, .allowReadWrite]
        controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let store: FeedingStore
        let babyName: String
        init(store: FeedingStore, babyName: String) { self.store = store; self.babyName = babyName }
        func itemTitle(for csc: UICloudSharingController) -> String? { "\(babyName)’s feeding journal" }
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            Task { @MainActor in store.errorMessage = error.localizedDescription }
        }
        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            Task { @MainActor in store.refresh() }
        }
        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            Task { @MainActor in store.refresh() }
        }
    }
}
