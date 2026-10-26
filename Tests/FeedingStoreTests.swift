import CoreData
import XCTest
@testable import BoobieTrackr3000

@MainActor
final class FeedingStoreTests: XCTestCase {
    var store: FeedingStore!
    var suite: String!

    override func setUp() async throws {
        suite = "BoobieTrackrTests.\(UUID().uuidString)"
        store = FeedingStore(inMemory: true, defaults: UserDefaults(suiteName: suite)!)
    }
    override func tearDown() async throws {
        store = nil
        UserDefaults.standard.removePersistentDomain(forName: suite)
    }

    func testNewBreastfeedingStartsTimerWithoutDuration() throws {
        let event = try store.add(kind: .breast, side: .left)
        XCTAssertEqual(store.running?.eventID, event.uuid)
        XCTAssertNil(event.duration)
        XCTAssertEqual(store.events.count, 1)
    }

    func testSwitchSavesPreviousDurationAndStartsOppositeSide() throws {
        let start = Date().addingTimeInterval(-120)
        let left = try store.add(kind: .breast, side: .left, start: start)
        try store.finish(eventID: left.uuid, switchSide: true, now: start.addingTimeInterval(90))
        XCTAssertEqual(left.duration?.doubleValue, 90)
        XCTAssertEqual(store.events.count, 2)
        XCTAssertEqual(store.runningEvent?.side, .right)
        XCTAssertNil(store.runningEvent?.duration)
        XCTAssertEqual(store.runningEvent?.journal, left.journal)
    }

    func testStopCommitsDurationAndClearsTimer() throws {
        let start = Date().addingTimeInterval(-600)
        let event = try store.add(kind: .breast, start: start)
        try store.finish(eventID: event.uuid, now: start.addingTimeInterval(600))
        XCTAssertEqual(event.duration?.doubleValue, 600)
        XCTAssertNil(store.running)
    }

    func testStartingAnotherFeedingDiscardsUnfinishedDuration() throws {
        let previous = try store.add(kind: .breast, start: Date().addingTimeInterval(-60))
        let next = try store.add(kind: .breast, side: .right)
        XCTAssertNil(previous.duration)
        XCTAssertEqual(store.running?.eventID, next.uuid)
        XCTAssertEqual(store.events.count, 2)
    }

    func testBottleAndPumpNeverStartTimers() throws {
        let previous = try store.add(kind: .breast)
        let bottle = try store.add(kind: .bottle, ml: 90)
        XCTAssertNil(store.running)
        XCTAssertNil(previous.duration)
        XCTAssertNil(bottle.side)
        XCTAssertEqual(bottle.volume?.doubleValue, 90)
        let pump = try store.add(kind: .pump, side: .both, ml: 120)
        XCTAssertNil(store.running)
        XCTAssertEqual(pump.side, .both)
    }

    func testDiscardRetainsEventAndNoDuration() throws {
        let event = try store.add(kind: .breast)
        store.setRunning(nil)
        XCTAssertNil(event.duration)
        XCTAssertEqual(store.events.count, 1)
        XCTAssertNil(store.defaults.data(forKey: "runningFeed"))
    }

    func testStaleLockScreenActionCannotStopAnotherFeeding() throws {
        let previous = try store.add(kind: .breast)
        let next = try store.add(kind: .breast, side: .right)
        XCTAssertThrowsError(try store.finish(eventID: previous.uuid, switchSide: true))
        XCTAssertEqual(store.running?.eventID, next.uuid)
        XCTAssertNil(previous.duration)
        XCTAssertEqual(store.events.count, 2)
    }

    func testDuplicateStopCannotOverwriteDuration() throws {
        let event = try store.add(kind: .breast, start: Date().addingTimeInterval(-60))
        try store.finish(eventID: event.uuid)
        let saved = event.duration
        XCTAssertThrowsError(try store.finish(eventID: event.uuid))
        XCTAssertEqual(event.duration, saved)
    }

    func testEditingStartUpdatesTimerAndPreservesMissingDuration() throws {
        let event = try store.add(kind: .breast)
        let earlier = Date().addingTimeInterval(-300)
        try store.update(event, kind: .breast, side: .right, start: earlier, ml: nil, duration: nil)
        XCTAssertEqual(store.running?.startedAt, earlier)
        XCTAssertEqual(event.side, .right)
        XCTAssertNil(event.duration)
    }

    func testChangingTypeDiscardsTimerAndClearsSide() throws {
        let event = try store.add(kind: .breast)
        try store.update(event, kind: .bottle, side: .left, start: event.startedAt, ml: 85, duration: nil)
        XCTAssertNil(store.running)
        XCTAssertNil(event.side)
        XCTAssertEqual(event.volume?.doubleValue, 85)
    }

    func testDeletingActiveFeedingClearsTimer() throws {
        let event = try store.add(kind: .breast)
        try store.delete(event)
        XCTAssertNil(store.running)
        XCTAssertTrue(store.events.isEmpty)
    }

    func testInvalidInputDoesNotMutateStoredEvent() throws {
        let event = try store.add(kind: .bottle, ml: 80)
        XCTAssertThrowsError(try store.update(event, kind: .bottle, side: .left, start: event.startedAt, ml: -1, duration: nil))
        XCTAssertEqual(event.volume?.doubleValue, 80)
        XCTAssertThrowsError(try store.add(kind: .breast, side: .both))
        XCTAssertThrowsError(try store.add(kind: .bottle, ml: .nan))
        XCTAssertThrowsError(try store.add(kind: .bottle, start: Date().addingTimeInterval(3600)))
        XCTAssertEqual(store.events.count, 1)
    }

    func testHistoricalFeedingCanBeAddedWithoutTimer() throws {
        let event = try store.add(kind: .breast, start: Date().addingTimeInterval(-86_400), startTimer: false)
        XCTAssertNil(store.running)
        XCTAssertNil(event.duration)
    }

    func testCSVPreservesBlankValuesAndSortsChronologically() throws {
        let start = Date(timeIntervalSince1970: 0)
        let csv = FeedingCSV.string(rows: [
            (UUID(), start.addingTimeInterval(60), .bottle, nil, 90.5, nil),
            (UUID(), start, .breast, .left, nil, 120)
        ])
        let lines = csv.components(separatedBy: "\r\n")
        XCTAssertEqual(lines[0], "id,start_time_utc,type,side,volume_ml,duration_seconds")
        XCTAssertTrue(lines[1].contains("1970-01-01T00:00:00.000Z"))
        XCTAssertTrue(lines[1].hasSuffix("\"Breast\",\"Left\",\"\",\"120\""))
        XCTAssertTrue(lines[2].hasSuffix("\"Bottle\",\"\",\"90.5\",\"\""))
    }

    func testExportUsesWholeJournalAndIncludesPump() throws {
        try store.add(kind: .breast, start: Date().addingTimeInterval(-86_400), startTimer: false)
        try store.add(kind: .pump, side: .both, ml: 100)
        let url = try store.exportCSV()
        let csv = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(csv.contains("\"Pump\",\"Both\",\"100.0\",\"\""))
        XCTAssertEqual(csv.components(separatedBy: "\r\n").count, 4)
    }

    func testRefreshUsesEditedStartAndStopsExternallyCompletedTimer() throws {
        let event = try store.add(kind: .breast)
        event.startedAt = Date().addingTimeInterval(-90)
        try store.container.viewContext.save()
        store.refresh()
        XCTAssertEqual(store.running?.startedAt, event.startedAt)
        event.duration = 90
        try store.container.viewContext.save()
        store.refresh()
        XCTAssertNil(store.running)
    }

    func testBabiesKeepSeparateHistoriesAndRememberSelection() throws {
        let first = try store.createBaby(name: "  Alex  ")
        let firstEvent = try store.add(kind: .breast, side: .right, startTimer: false)
        let second = try store.createBaby(name: "Sam")
        XCTAssertTrue(store.events.isEmpty)
        let secondEvent = try store.add(kind: .bottle, ml: 75)
        XCTAssertEqual(store.events.map(\.uuid), [secondEvent.uuid])
        XCTAssertEqual(secondEvent.journal, second)
        store.selectedJournalID = first.uuid.uuidString
        XCTAssertEqual(store.events.map(\.uuid), [firstEvent.uuid])
        XCTAssertEqual(store.defaults.string(forKey: "selectedJournal"), first.uuid.uuidString)
        XCTAssertEqual(first.name, "Alex")
        XCTAssertEqual(store.journals.count, 2)
    }

    func testRenamingExistingBabyPreservesJournalAndFeedings() throws {
        let event = try store.add(kind: .breast, startTimer: false)
        let journal = try XCTUnwrap(event.journal)
        let id = journal.objectID
        try store.renameBaby(journal, name: "  Robin  ")
        XCTAssertEqual(store.activeJournal?.name, "Robin")
        XCTAssertEqual(store.activeJournal?.objectID, id)
        XCTAssertEqual(store.events.map(\.uuid), [event.uuid])
        XCTAssertThrowsError(try store.renameBaby(journal, name: " \n "))
        XCTAssertEqual(journal.name, "Robin")
        XCTAssertThrowsError(try store.createBaby(name: " "))
        XCTAssertEqual(store.journals.count, 1)
    }

    func testSwitchingBabiesKeepsTimerAndSwitchActionInOriginalJournal() throws {
        let first = try store.createBaby(name: "Alex")
        let started = Date().addingTimeInterval(-90)
        let event = try store.add(kind: .breast, side: .left, start: started)
        let second = try store.createBaby(name: "Sam")
        XCTAssertTrue(store.events.isEmpty)
        XCTAssertEqual(store.runningEvent?.uuid, event.uuid)
        try store.finish(eventID: event.uuid, switchSide: true)
        XCTAssertEqual(store.activeJournal, second)
        XCTAssertTrue(store.events.isEmpty)
        XCTAssertEqual(store.runningEvent?.journal, first)
        XCTAssertEqual(store.runningEvent?.side, .right)
        XCTAssertNotNil(event.duration)
        let next = try XCTUnwrap(store.runningEvent)
        try store.finish(eventID: next.uuid)
        XCTAssertNil(store.running)
        store.selectedJournalID = first.uuid.uuidString
        XCTAssertEqual(store.events.count, 2)
    }

    func testExportIncludesOnlySelectedBaby() throws {
        let first = try store.createBaby(name: "Alex")
        let firstEvent = try store.add(kind: .breast, startTimer: false)
        try store.createBaby(name: "Sam")
        let secondEvent = try store.add(kind: .bottle, ml: 80)
        store.selectedJournalID = first.uuid.uuidString
        let csv = try String(contentsOf: store.exportCSV(), encoding: .utf8)
        XCTAssertTrue(csv.contains(firstEvent.uuid.uuidString))
        XCTAssertFalse(csv.contains(secondEvent.uuid.uuidString))
    }

    func testInvalidBabySelectionFallsBackWithoutCombiningHistories() throws {
        try store.createBaby(name: "Alex")
        let firstEvent = try store.add(kind: .bottle, ml: 90)
        try store.createBaby(name: "Sam")
        try store.add(kind: .pump, side: .both)
        store.selectedJournalID = UUID().uuidString
        XCTAssertEqual(store.events.map(\.uuid), [firstEvent.uuid])
    }

    func testDeletingBabyRemovesOnlyTheirFeedingsAndTimer() throws {
        let first = try store.createBaby(name: "Alex")
        let kept = try store.add(kind: .bottle, ml: 90)
        let second = try store.createBaby(name: "Sam")
        try store.add(kind: .pump, side: .both)
        try store.add(kind: .breast)
        try store.deleteBaby(second)
        XCTAssertEqual(store.journals.map(\.uuid), [first.uuid])
        XCTAssertEqual(store.activeJournal, first)
        XCTAssertEqual(store.events.map(\.uuid), [kept.uuid])
        XCTAssertNil(store.running)
        XCTAssertEqual(try store.container.viewContext.count(for: NSFetchRequest<FeedingEvent>(entityName: "FeedingEvent")), 1)
    }

    func testDeletingAnotherBabyPreservesRunningTimerAndSelection() throws {
        let first = try store.createBaby(name: "Alex")
        try store.add(kind: .bottle)
        let second = try store.createBaby(name: "Sam")
        let event = try store.add(kind: .breast)
        try store.deleteBaby(first)
        XCTAssertEqual(store.activeJournal, second)
        XCTAssertEqual(store.runningEvent, event)
        XCTAssertEqual(store.running?.eventID, event.uuid)
        XCTAssertEqual(store.selectedJournalID, second.uuid.uuidString)
    }

    func testDeletingLastBabyLeavesNoOrphanFeedingsAndAllowsNewBaby() throws {
        let baby = try store.createBaby(name: "Alex")
        let oldID = baby.uuid
        try store.add(kind: .breast)
        try store.deleteBaby(baby)
        XCTAssertTrue(store.journals.isEmpty)
        XCTAssertTrue(store.events.isEmpty)
        XCTAssertNil(store.activeJournal)
        XCTAssertNil(store.running)
        XCTAssertEqual(store.selectedJournalID, "")
        XCTAssertEqual(try store.container.viewContext.count(for: NSFetchRequest<FeedingEvent>(entityName: "FeedingEvent")), 0)
        let next = try store.createBaby(name: "Sam")
        XCTAssertNotEqual(next.uuid, oldID)
        XCTAssertEqual(store.activeJournal, next)
        XCTAssertTrue(store.events.isEmpty)
    }
}
