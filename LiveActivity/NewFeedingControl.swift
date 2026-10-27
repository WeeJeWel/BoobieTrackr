import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 18.0, *)
struct NewFeedingControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "nl.weejewel.BoobieTrackr3000.newFeeding") {
            ControlWidgetButton(action: NewFeedingIntent()) {
                Label("New Feeding", systemImage: "plus.circle.fill")
            }
        }
        .displayName("New Feeding")
        .description("Open a new feeding for the selected baby.")
    }
}
