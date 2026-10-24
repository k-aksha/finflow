#if os(iOS)
import ActivityKit
import SwiftUI
import WidgetKit

struct CaptureLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CaptureActivityAttributes.self) { context in
            HStack(spacing: 12) {
                IslandFace(side: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.state.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(context.state.detail.isEmpty ? "Listening…" : context.state.detail)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .activityBackgroundTint(Color(red: 0.07, green: 0.07, blue: 0.07))
            .widgetURL(URL(string: "finflow://capture"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    IslandFace(side: 44)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: context.state.symbol)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(context.state.detail.isEmpty ? "Say the amount and what it was for." : context.state.detail)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                IslandFace(side: 22)
            } compactTrailing: {
                Image(systemName: context.state.symbol)
                    .foregroundStyle(.white)
            } minimal: {
                Image(systemName: "mic.fill")
                    .foregroundStyle(.white)
            }
            .widgetURL(URL(string: "finflow://capture"))
            .keylineTint(Color(red: 0.2, green: 0.2, blue: 0.2))
        }
    }
}
#endif
