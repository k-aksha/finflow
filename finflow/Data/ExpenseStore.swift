import Foundation
import os
import SwiftData
import WidgetKit

enum ExpenseStoreError: LocalizedError {
    case nothingToSave

    var errorDescription: String? {
        switch self {
        case .nothingToSave:
            "Enter an amount such as 1500 or one lakh, and what it was for."
        }
    }
}

enum ExpenseStore {
    private static let log = Logger(subsystem: "in.akshaux.finflow", category: "store")

    static func save(_ drafts: [DraftExpense], in context: ModelContext, spokenOn: Date = .now) throws {
        let records = drafts.compactMap { Expense(draft: $0, spokenOn: spokenOn) }
        guard !records.isEmpty else { throw ExpenseStoreError.nothingToSave }
        for record in records {
            context.insert(record)
        }
        do {
            try context.save()
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            log.error("Could not save expenses: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    static func erase(_ expenses: [Expense], in context: ModelContext) throws {
        for expense in expenses {
            context.delete(expense)
        }
        do {
            try context.save()
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            log.error("Could not erase expenses: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}

extension Expense {
    convenience init?(draft: DraftExpense, spokenOn: Date) {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard draft.amount.isFinite, draft.amount > 0, !title.isEmpty else { return nil }
        let detail = draft.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeDetail = detail.isEmpty ? title : detail
        self.init(
            title: String(title.prefix(80)),
            detail: String(safeDetail.prefix(280)),
            amount: draft.amount,
            category: ExpenseCategory.normalize(draft.category),
            spokenOn: spokenOn
        )
    }
}
