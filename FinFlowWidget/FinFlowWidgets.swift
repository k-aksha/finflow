import SwiftUI
import WidgetKit

@main
struct FinFlowWidgets: WidgetBundle {
    var body: some Widget {
        TodayExpenseWidget()
        #if os(iOS)
        CaptureLiveActivity()
        LogExpenseControl()
        #endif
    }
}
