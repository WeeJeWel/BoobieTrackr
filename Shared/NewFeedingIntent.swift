import AppIntents

struct NewFeedingIntent: OpenIntent {
    static var title: LocalizedStringResource = "New Feeding"
    static var description = IntentDescription("Open a new feeding for the selected baby.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Screen") var target: FeedingScreen

    init() { target = .newFeeding }

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        FeedingStore.shared.newFeedingRequested = true
        #endif
        return .result()
    }
}

enum FeedingScreen: String, AppEnum {
    case newFeeding
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Screen")
    static var caseDisplayRepresentations: [FeedingScreen: DisplayRepresentation] = [
        .newFeeding: DisplayRepresentation(title: "New Feeding")
    ]
}

#if !WIDGET_EXTENSION
struct FeedingShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: NewFeedingIntent(), phrases: [
            "New feeding in \(.applicationName)",
            "Start a feeding in \(.applicationName)"
        ], shortTitle: "New Feeding", systemImageName: "plus.circle.fill")
    }
    static var shortcutTileColor: ShortcutTileColor = .pink
}
#endif
