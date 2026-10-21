import Foundation
import SwiftData

@Model
nonisolated final class Expense {
    var id: UUID
    var title: String
    var detail: String
    var amount: Double
    var category: String
    var spokenOn: Date
    var createdAt: Date

    init(
        title: String,
        detail: String,
        amount: Double,
        category: String,
        spokenOn: Date,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.title = title
        self.detail = detail
        self.amount = amount
        self.category = category
        self.spokenOn = spokenOn
        self.createdAt = createdAt
    }
}

enum ExpenseCategory {
    static let all = [
        "Food & drink",
        "Transport",
        "Shopping",
        "Bills",
        "Health",
        "Entertainment",
        "Other"
    ]

    static func normalize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = all.first(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return match
        }
        return infer(from: trimmed)
    }

    static func infer(from text: String) -> String {
        let value = text.lowercased()
        if value.contains("coffee") || value.contains("biryani") || value.contains("biriyani")
            || value.contains("lunch") || value.contains("dinner") || value.contains("food")
            || value.contains("tea") || value.contains("snack") {
            return "Food & drink"
        }
        if value.contains("petrol") || value.contains("uber") || value.contains("ola")
            || value.contains("bus") || value.contains("metro") || value.contains("fuel")
            || value.contains("cab") {
            return "Transport"
        }
        if value.contains("bill") || value.contains("rent") || value.contains("recharge")
            || value.contains("electric") {
            return "Bills"
        }
        if value.contains("medicine") || value.contains("doctor") || value.contains("pharmacy") {
            return "Health"
        }
        if value.contains("movie") || value.contains("game") {
            return "Entertainment"
        }
        if value.contains("shop") || value.contains("amazon") || value.contains("clothes") {
            return "Shopping"
        }
        return "Other"
    }
}
