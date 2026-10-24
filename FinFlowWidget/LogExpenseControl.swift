#if os(iOS)
import AppIntents
import SwiftUI
import WidgetKit

struct LogExpenseControl: ControlWidget {
    static let kind = "in.akshaux.finflow.log"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: LogExpenseIntent()) {
                Label("Log expense", systemImage: "mic.fill")
            }
        }
        .displayName("Log an expense")
        .description("Open FinFlow and start listening.")
    }
}
#endif
