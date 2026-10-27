import ActivityKit
import Foundation

extension FeedingStore {
    func syncLiveActivity() async {
        if liveActivitySyncing { liveActivitySyncAgain = true; return }
        liveActivitySyncing = true
        defer { liveActivitySyncing = false }
        repeat {
            liveActivitySyncAgain = false
            guard let running, let event = runningEvent else {
                for activity in Activity<FeedingAttributes>.activities {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
                continue
            }
            let state = FeedingAttributes.ContentState(eventID: running.eventID,
                                                      side: (event.side ?? .left).rawValue,
                                                      startedAt: running.startedAt,
                                                      babyName: event.journal?.name)
            let content = ActivityContent(state: state, staleDate: nil)
            if let activity = Activity<FeedingAttributes>.activities.first(where: { $0.activityState == .active }) {
                await activity.update(content)
                defaults.set(running.eventID.uuidString, forKey: "liveActivityEventID")
            } else if ActivityAuthorizationInfo().areActivitiesEnabled {
                do {
                    let activity = try Activity.request(attributes: FeedingAttributes(), content: content, pushType: nil)
                    defaults.set(running.eventID.uuidString, forKey: "liveActivityEventID")
                    observe(activity)
                } catch {
                    errorMessage = String(localized: "Feeding saved. The Lock Screen timer couldn’t start: \(error.localizedDescription)")
                }
            }
        } while liveActivitySyncAgain
    }

    func restoreLiveActivity() async {
        let activities = Activity<FeedingAttributes>.activities
        if let running {
            let activity = activities.first { $0.content.state.eventID == running.eventID }
            // A dismissed/expired activity is an abandoned timer, never a completed feeding.
            if activity == nil || activity?.activityState == .dismissed || activity?.activityState == .ended {
                if defaults.string(forKey: "liveActivityEventID") == running.eventID.uuidString { setRunning(nil) }
            }
        }
        for activity in activities { observe(activity) }
        await syncLiveActivity()
    }

    private func observe(_ activity: Activity<FeedingAttributes>) {
        Task { @MainActor [weak self] in
            for await state in activity.activityStateUpdates {
                guard let self else { return }
                if state == .dismissed || state == .ended {
                    if self.running?.eventID == activity.content.state.eventID {
                        self.setRunning(nil)
                    }
                    break
                }
            }
        }
    }
}
