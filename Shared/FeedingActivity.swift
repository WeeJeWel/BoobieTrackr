import ActivityKit
import AppIntents
import Foundation

struct FeedingAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var eventID: UUID
        var side: String
        var startedAt: Date
        var babyName: String? = nil
    }
}

struct StopFeedingIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Done"
    static var description = IntentDescription("Save the elapsed breastfeeding duration.")
    @Parameter(title: "Feeding ID") var eventID: String

    init() {}
    init(eventID: String) { self.eventID = eventID }

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        guard let id = UUID(uuidString: eventID) else { throw FeedingError.missingTimer }
        try FeedingStore.shared.finish(eventID: id)
        await FeedingStore.shared.syncLiveActivity()
        #endif
        return .result()
    }
}

struct SwitchBreastIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Switch sides"
    static var description = IntentDescription("Save this duration and immediately start the other breast.")
    @Parameter(title: "Feeding ID") var eventID: String

    init() {}
    init(eventID: String) { self.eventID = eventID }

    @MainActor
    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        guard let id = UUID(uuidString: eventID) else { throw FeedingError.missingTimer }
        try FeedingStore.shared.finish(eventID: id, switchSide: true)
        await FeedingStore.shared.syncLiveActivity()
        #endif
        return .result()
    }
}
