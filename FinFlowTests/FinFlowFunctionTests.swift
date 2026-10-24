import SwiftData
import XCTest
@testable import finflow

@MainActor
final class FinFlowFunctionTests: XCTestCase {
    func testSpokenAmountsBecomeRupeeExpenses() {
        let cases: [(String, Double, String, String)] = [
            ("500 for coffee", 500, "Coffee", "Food & drink"),
            ("one lakh rupees for rent", 100_000, "Rent", "Bills"),
            ("rupees one lakh", 100_000, "Expense", "Other"),
            ("two and a half lakh for rent", 250_000, "Rent", "Bills"),
            ("1,00,000 for rent", 100_000, "Rent", "Bills"),
            ("1.5 lakh for shopping", 150_000, "Shopping", "Shopping"),
            ("um one lakh rupees for rent", 100_000, "Rent", "Bills"),
            ("uh five hundred for coffee", 500, "Coffee", "Food & drink"),
            ("two coffees for five hundred rupees", 500, "2 Coffees", "Food & drink"),
            ("you know, like petrol for eighty", 80, "Petrol", "Transport"),
            ("rs.250 for medicine", 250, "Medicine", "Health"),
            ("₹400 for a movie", 400, "Movie", "Entertainment"),
            ("one crore for a house", 10_000_000, "House", "Other"),
            ("one lack rupees for rent", 100_000, "Rent", "Bills"),
            ("three teas for two hundred rupees", 200, "3 Teas", "Food & drink")
        ]

        for sample in cases {
            let item = LocalExpenseParser.parse(sample.0).first
            XCTAssertEqual(item?.amount, sample.1, sample.0)
            XCTAssertEqual(item?.title, sample.2, sample.0)
            XCTAssertEqual(item?.category, sample.3, sample.0)
            XCTAssertFalse(item?.title.localizedCaseInsensitiveContains("um") == true, sample.0)
            XCTAssertFalse(item?.title.localizedCaseInsensitiveContains("like") == true, sample.0)
        }
    }

    func testCombinedPurchasesDropARepeatedTotal() {
        let items = LocalExpenseParser.parse("coffee 200 and tea 50 total 250")
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.map(\.title), ["Coffee", "Tea"])
        XCTAssertEqual(items.reduce(0) { $0 + $1.amount }, 250)
    }

    func testSeparatePurchasesStaySeparate() {
        let items = LocalExpenseParser.parse("paid 80 for bus and 400 for dinner")
        XCTAssertEqual(items.map(\.amount), [80, 400])
        XCTAssertEqual(items.map(\.category), ["Transport", "Food & drink"])
    }

    func testNotesWithoutAnAmountAreNotExpenses() {
        XCTAssertTrue(LocalExpenseParser.parse("").isEmpty)
        XCTAssertTrue(LocalExpenseParser.parse("   ").isEmpty)
        XCTAssertTrue(LocalExpenseParser.parse("hello there").isEmpty)
        XCTAssertTrue(LocalExpenseParser.parse("um yeah you know").isEmpty)
    }

    func testRecoveryAcceptsWordsOrDigitsAndRejectsNoise() {
        let spoken = DraftExpense.recovered(amountText: "one lakh", title: "rent")
        XCTAssertEqual(spoken?.amount, 100_000)
        XCTAssertEqual(spoken?.title, "Rent")
        XCTAssertEqual(spoken?.category, "Bills")

        let typed = DraftExpense.recovered(amountText: "1,500", title: "")
        XCTAssertEqual(typed?.amount, 1_500)
        XCTAssertEqual(typed?.title, "Expense")

        XCTAssertNil(DraftExpense.recovered(amountText: "hello", title: ""))
        XCTAssertNil(DraftExpense.recovered(amountText: "0", title: "coffee"))
    }

    func testCategoriesStayInTheKnownSet() {
        XCTAssertEqual(ExpenseCategory.normalize("food & drink"), "Food & drink")
        XCTAssertEqual(ExpenseCategory.normalize("transport"), "Transport")
        XCTAssertEqual(ExpenseCategory.infer(from: "uber to the airport"), "Transport")
        XCTAssertEqual(ExpenseCategory.infer(from: "pharmacy bill"), "Health")
        XCTAssertEqual(ExpenseCategory.infer(from: "amazon clothes"), "Shopping")
        XCTAssertEqual(ExpenseCategory.infer(from: "something else"), "Other")
        for name in ExpenseCategory.all {
            XCTAssertEqual(ExpenseCategory.normalize(name), name)
        }
    }

    func testRupeeFormattingUsesIndianGrouping() {
        let formatted = ExpenseMoney.rupees(100_000)
        XCTAssertTrue(formatted.contains("1,00,000"), formatted)
        XCTAssertTrue(formatted.contains("00"), formatted)
    }

    func testSavedExpenseKeepsASafeTitleAndDropsInvalidDrafts() throws {
        let spokenOn = Date(timeIntervalSince1970: 1_700_000_000)
        let longTitle = String(repeating: "a", count: 120)
        let saved = try XCTUnwrap(Expense(draft: DraftExpense(title: longTitle, detail: longTitle, amount: 42, category: "nope"), spokenOn: spokenOn))
        XCTAssertEqual(saved.title.count, 80)
        XCTAssertEqual(saved.detail.count, 120)
        XCTAssertEqual(saved.category, "Other")
        XCTAssertEqual(saved.amount, 42)
        XCTAssertEqual(saved.spokenOn, spokenOn)

        XCTAssertNil(Expense(draft: DraftExpense(title: "Coffee", detail: "Coffee", amount: 0, category: "Food & drink"), spokenOn: spokenOn))
        XCTAssertNil(Expense(draft: DraftExpense(title: "   ", detail: "Coffee", amount: 10, category: "Food & drink"), spokenOn: spokenOn))
    }

    func testTodayTotalIgnoresOtherDaysAndEraseClearsTheDay() throws {
        let container = try ModelContainer(
            for: Expense.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let now = Date()
        let yesterday = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: now))
        try ExpenseStore.save(
            [DraftExpense(title: "Coffee", detail: "Coffee", amount: 120, category: "Food & drink")],
            in: context,
            spokenOn: now
        )
        try ExpenseStore.save(
            [DraftExpense(title: "Rent", detail: "Rent", amount: 20_000, category: "Bills")],
            in: context,
            spokenOn: yesterday
        )

        let rows = try context.fetch(FetchDescriptor<Expense>())
        let todays = rows.filter { Calendar.current.isDate($0.spokenOn, inSameDayAs: now) }
        XCTAssertEqual(todays.count, 1)
        XCTAssertEqual(todays.reduce(0) { $0 + $1.amount }, 120)

        try ExpenseStore.erase(todays, in: context)
        let remaining = try context.fetch(FetchDescriptor<Expense>())
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.title, "Rent")

        XCTAssertThrowsError(try ExpenseStore.save([], in: context))
    }

    func testWidgetLaunchStartsListeningOnlyOnce() throws {
        _ = CaptureLaunch.take()
        XCTAssertFalse(CaptureLaunch.isPending)
        CaptureLaunch.request()
        try XCTSkipUnless(CaptureLaunch.isPending, "App Group defaults are unavailable for this test host")
        XCTAssertTrue(CaptureLaunch.take())
        XCTAssertFalse(CaptureLaunch.take())
        XCTAssertFalse(CaptureLaunch.isPending)
    }
}
