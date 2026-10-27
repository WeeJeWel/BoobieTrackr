import ActivityKit
import SwiftUI
import WidgetKit

@main
struct FeedingWidgets: WidgetBundle {
    var body: some Widget {
        FeedingActivityWidget()
        if #available(iOS 18.0, *) { NewFeedingControl() }
    }
}

// iOS 18+ suppresses per-second Live Activity digit animations (Apple issue 115906895).
// Keep the system timer: an app-driven counter stops updating when the app is suspended.
struct FeedingActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FeedingAttributes.self) { context in
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    FeedingIcon(kind: .breast, side: FeedingSide(rawValue: context.state.side))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.babyName ?? String(localized: "Our baby")).font(.headline).lineLimit(1)
                        Text((FeedingSide(rawValue: context.state.side) ?? .left).breastTitle).font(.caption).foregroundStyle(Palette.muted)
                    }
                    Spacer(minLength: 0)
                    Text(timerInterval: context.state.startedAt...context.state.startedAt.addingTimeInterval(86_400), countsDown: false)
                        .contentTransition(.numericText(countsDown: false))
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .monospacedDigit().multilineTextAlignment(.trailing)
                        .frame(width: 92)
                        .foregroundStyle(Palette.accent)
                }
                HStack(spacing: 10) {
                    Button(intent: StopFeedingIntent(eventID: context.state.eventID.uuidString)) {
                        Label("Done", systemImage: "stop.fill").lineLimit(1).minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                    }
                    .tint(Palette.elevated)
                    Button(intent: SwitchBreastIntent(eventID: context.state.eventID.uuidString)) {
                        Text((FeedingSide(rawValue: context.state.side) ?? .left).opposite.switchTitle)
                            .lineLimit(1).minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                    }
                    .tint(Palette.accent).foregroundStyle(Palette.background)
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
            }
            .padding(18)
            .activityBackgroundTint(Palette.background)
            .activitySystemActionForegroundColor(Palette.accent)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.babyName ?? String(localized: "Our baby")).font(.caption).lineLimit(1)
                        Label { Text((FeedingSide(rawValue: context.state.side) ?? .left).title) } icon: {
                            FeedingEventSymbol(kind: .breast, side: FeedingSide(rawValue: context.state.side), size: 20)
                        }
                    }
                    .foregroundStyle(Palette.accent).padding(.top, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.startedAt...context.state.startedAt.addingTimeInterval(86_400), countsDown: false)
                        .contentTransition(.numericText(countsDown: false))
                        .monospacedDigit().foregroundStyle(Palette.cream).padding(.top, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Button(intent: StopFeedingIntent(eventID: context.state.eventID.uuidString)) {
                            Label("Done", systemImage: "stop.fill").lineLimit(1).minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity)
                        }
                        .tint(Palette.elevated)
                        Button(intent: SwitchBreastIntent(eventID: context.state.eventID.uuidString)) {
                            Text((FeedingSide(rawValue: context.state.side) ?? .left).opposite.switchTitle)
                                .lineLimit(1).minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity)
                        }
                        .tint(Palette.accent).foregroundStyle(Palette.background)
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 10)
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    FeedingEventSymbol(kind: .breast, side: FeedingSide(rawValue: context.state.side), size: 20)
                    Text(context.state.side == "left" ? String(localized: "L", comment: "Abbreviation for left breast in the Dynamic Island") : String(localized: "R", comment: "Abbreviation for right breast in the Dynamic Island"))
                }.foregroundStyle(Palette.accent)
            } compactTrailing: {
                Text(timerInterval: context.state.startedAt...context.state.startedAt.addingTimeInterval(86_400), countsDown: false)
                    .contentTransition(.numericText(countsDown: false))
                    .monospacedDigit().frame(width: 50).foregroundStyle(Palette.accent)
            } minimal: {
                FeedingEventSymbol(kind: .breast, side: FeedingSide(rawValue: context.state.side), size: 20).foregroundStyle(Palette.accent)
            }
            .keylineTint(Palette.accent)
        }
    }
}
