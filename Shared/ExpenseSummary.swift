import Foundation
import SwiftData

nonisolated enum ExpenseMoney {
    static func rupees(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.locale = Locale(identifier: "en_IN")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "₹\(amount)"
    }
}

nonisolated enum ExpenseSummary {
    struct Today: Sendable {
        var total: Double
        var count: Int
    }

    static func today(now: Date = .now) -> Today {
        guard let container = try? FinFlowStore.container() else {
            return Today(total: 0, count: 0)
        }
        let context = ModelContext(container)
        let rows = (try? context.fetch(FetchDescriptor<Expense>())) ?? []
        let todays = rows.filter { Calendar.current.isDate($0.spokenOn, inSameDayAs: now) }
        let total = todays.reduce(0) { $0 + $1.amount }
        return Today(total: total, count: todays.count)
    }
}
