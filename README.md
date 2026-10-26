# BoobieTrackr

Native SwiftUI feeding journal for iPhone (iOS 17+) and Apple Watch (watchOS 10+). Dark colors only, with a #f06992 accent and outline breast icons with a dotted outline on the inactive side; no third-party dependencies.

## Run

Open `BoobieTrackr3000.xcodeproj`, select the `BoobieTrackr3000` scheme, and run on an iPhone. The project includes the Watch app and the Live Activity extension.

Signing defaults to the Emile B.V. team (`FY9967QY8V`). Xcode must be signed into that developer account. The iPhone and Watch targets need iCloud/CloudKit and push notification capabilities for `iCloud.nl.weejewel.BoobieTrackr3000`. The Live Activity extension uses the containing app’s process for its action intents and does not need access to the database itself.

`project.yml` is the project source of truth. After changing targets or adding files, run `xcodegen generate`. The generated Xcode project is included, so XcodeGen is not needed just to build it.

## Behavior

- The header baby menu lists private and shared babies and offers New Baby. Manage Baby in the three-dot menu opens an autosaving name field and Delete Baby with native confirmation. Deletion removes that baby and their feedings for everyone sharing the journal, clears their active timer, and selects another available baby. Each baby uses an existing journal record, so names, feedings, and sharing keep their identities without a schema migration. Selection is remembered per device; the Watch has its own baby picker. Calendar dots, side suggestions, sharing, and CSV export use the selected baby. Switching babies keeps the current timer running for its original baby; only one timer runs per device.

- The timeline scrolls continuously between days. It keeps a bounded window of days and extends it after scrolling stops, preserving the visible row and its position. Visible-day observation is separate from date-jump commands, so loading history cannot repeatedly scroll itself backward. The timeline uses standard iOS scrolling and ends at the current hour. A pinned Today chip returns to the current day and resets the horizontal date strip. Crossing midnight updates the day picker with a selection haptic. Events within an hour are stacked so they remain tappable. The header calendar marks days with events using peach dots and jumps to any past date; the three-dot menu contains sharing and CSV export.
- Long-press empty timeline space to open New Feeding with the current time. Moving the finger cancels the long press so scrolling stays native.
- New Feeding suggests the opposite side of the latest breastfeeding event in the active journal, ignoring bottle and pump entries. With no prior breastfeeding event, it defaults to Left. The side can still be changed manually.
- Breastfeeding starts a timer by default. The Start Timer choice is remembered for subsequent feedings. Disable it when entering an old feeding if no live timer is wanted. Bottle and pump entries never start timers.
- Done saves elapsed seconds. Switch to Left/Right saves the current duration and creates the opposite-side feeding atomically. Starting another event, dismissing an activity, or allowing it to expire discards the unfinished timer’s duration and keeps the feeding.
- On iOS 27 and later, swipe left on a timeline event to reveal Delete. Deletion from the timeline or editor uses a native Delete/Cancel alert.
- Tapping an event opens an autosaving editor. Optional milk volume and duration can be cleared. Invalid input leaves the last valid value intact and displays an error.
- The export button shares a UTF-8 CSV containing the complete active journal, with UTC ISO-8601 timestamps, milliliters, and duration in seconds. Missing values stay empty.
- Watch entry supports one-tap Left, Right, or Bottle, plus a Pump side selector. Watch timers have Done and switch controls. Milk amounts can be edited later on iPhone. The Watch uses its own local timer and syncs feeding records through iCloud; it does not remotely start an iPhone Live Activity.

## iCloud sharing

Core Data saves locally and mirrors private and shared CloudKit stores. A journal is the shared root, with all feeding events related to it. Use Invite Partner in the three-dot menu to invite a partner; invitations are private and read/write. There are no app-specific roles. Apple retains its owner/participant distinction for managing the share itself. Sharing is invitation-based and does not happen automatically through Apple Family Sharing.

Accept invitations on iPhone. The app handles invitations on both cold launch and an existing scene. Shared journals sync to the participant’s other devices, including Watch. Private and shared babies appear together in the header picker.

The generated CloudKit schema was deployed to production in CloudKit Console on October 26, 2026. Deploy any future schema additions before distributing builds that depend on them. A real two-account test is required to validate invitation acceptance, bidirectional changes, offline recovery, and Watch syncing. Simulator tests do not establish those results.

## Verification

Run the `BoobieTrackr3000` scheme’s tests in Xcode, or:

```sh
xcodebuild -project BoobieTrackr3000.xcodeproj -scheme BoobieTrackr3000 \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO test
```

Tests cover timer switching, stop/discard behavior, stale and duplicate actions, edits, deletion, input validation, historical events, and CSV serialization/export. Simulator builds use local storage, because unsigned background launches cannot access CloudKit. A launch with `--demo` uses a separate local journal with sample events. Neither affects real iCloud data.

The app icon can be regenerated with `swift Scripts/GenerateIcon.swift`.

Apple references: [Core Data sharing](https://developer.apple.com/documentation/coredata/sharing-core-data-objects-between-icloud-users), [Live Activity lifecycle](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities).
