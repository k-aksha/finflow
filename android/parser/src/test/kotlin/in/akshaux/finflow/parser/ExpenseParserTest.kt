package `in`.akshaux.finflow.parser

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class ExpenseParserTest {
    @Test
    fun digitsForAPurchase() {
        val items = LocalExpenseParser.parse("500 for coffee")
        assertEquals(1, items.size)
        assertEquals(500.0, items[0].amount)
        assertEquals("Coffee", items[0].title)
        assertEquals("Food & drink", items[0].category)
    }

    @Test
    fun oneLakhRupees() {
        val items = LocalExpenseParser.parse("one lakh rupees for rent")
        assertEquals(1, items.size)
        assertEquals(100_000.0, items[0].amount)
        assertEquals("Rent", items[0].title)
        assertEquals("Bills", items[0].category)
    }

    @Test
    fun rupeesBeforeTheAmount() {
        val items = LocalExpenseParser.parse("rupees one lakh")
        assertEquals(1, items.size)
        assertEquals(100_000.0, items[0].amount)
        assertEquals("Expense", items[0].title)
    }

    @Test
    fun twoAndAHalfLakh() {
        val items = LocalExpenseParser.parse("two and a half lakh for rent")
        assertEquals(250_000.0, items.single().amount)
    }

    @Test
    fun indianGroupingAndGluedLakh() {
        assertEquals(100_000.0, LocalExpenseParser.parse("1,00,000 for rent").single().amount)
        assertEquals(150_000.0, LocalExpenseParser.parse("1.5 lakh for shopping").single().amount)
    }

    @Test
    fun dropsATrailingTotal() {
        val items = LocalExpenseParser.parse("coffee 200 and tea 50 total 250")
        assertEquals(2, items.size)
        assertEquals(250.0, items.sumOf { it.amount })
    }

    @Test
    fun dropsFillerWords() {
        val items = LocalExpenseParser.parse("um one lakh rupees for rent")
        assertEquals(100_000.0, items.single().amount)
        assertEquals("Rent", items.single().title)
    }

    @Test
    fun spokenAmountBecomesDigits() {
        val items = LocalExpenseParser.parse("uh five hundred for coffee")
        assertEquals(500.0, items.single().amount)
        assertEquals("Coffee", items.single().title)
    }

    @Test
    fun spokenCountInTheNameBecomesDigits() {
        val items = LocalExpenseParser.parse("two coffees for five hundred rupees")
        assertEquals(500.0, items.single().amount)
        assertEquals("2 Coffees", items.single().title)
    }

    @Test
    fun recoveryAcceptsWordsOrDigits() {
        val spoken = LocalExpenseParser.recovered("one lakh", "rent")
        assertEquals(100_000.0, spoken?.amount)
        assertEquals("Rent", spoken?.title)
        assertEquals("Bills", spoken?.category)
        val typed = LocalExpenseParser.recovered("1,500", "")
        assertEquals(1_500.0, typed?.amount)
        assertEquals("Expense", typed?.title)
        assertTrue(LocalExpenseParser.recovered("hello", "") == null)
        assertTrue(LocalExpenseParser.recovered("0", "coffee") == null)
    }

    @Test
    fun spokenAmountsMatchTheAppleParser() {
        val cases = listOf(
            Phrase("500 for coffee", 500.0, "Coffee", "Food & drink"),
            Phrase("one lakh rupees for rent", 100_000.0, "Rent", "Bills"),
            Phrase("rupees one lakh", 100_000.0, "Expense", "Other"),
            Phrase("two and a half lakh for rent", 250_000.0, "Rent", "Bills"),
            Phrase("1,00,000 for rent", 100_000.0, "Rent", "Bills"),
            Phrase("1.5 lakh for shopping", 150_000.0, "Shopping", "Shopping"),
            Phrase("um one lakh rupees for rent", 100_000.0, "Rent", "Bills"),
            Phrase("uh five hundred for coffee", 500.0, "Coffee", "Food & drink"),
            Phrase("two coffees for five hundred rupees", 500.0, "2 Coffees", "Food & drink"),
            Phrase("you know, like petrol for eighty", 80.0, "Petrol", "Transport"),
            Phrase("rs.250 for medicine", 250.0, "Medicine", "Health"),
            Phrase("₹400 for a movie", 400.0, "Movie", "Entertainment"),
            Phrase("one crore for a house", 10_000_000.0, "House", "Other"),
            Phrase("one lack rupees for rent", 100_000.0, "Rent", "Bills"),
            Phrase("three teas for two hundred rupees", 200.0, "3 Teas", "Food & drink"),
        )
        for (sample in cases) {
            val item = LocalExpenseParser.parse(sample.spoken).single()
            assertEquals(sample.amount, item.amount, sample.spoken)
            assertEquals(sample.title, item.title, sample.spoken)
            assertEquals(sample.category, item.category, sample.spoken)
            assertTrue(!item.title.contains("um", ignoreCase = true))
            assertTrue(!item.title.contains("like", ignoreCase = true))
        }
    }

    @Test
    fun separatePurchasesStaySeparate() {
        val items = LocalExpenseParser.parse("paid 80 for bus and 400 for dinner")
        assertEquals(listOf(80.0, 400.0), items.map { it.amount })
        assertEquals(listOf("Transport", "Food & drink"), items.map { it.category })
    }

    @Test
    fun notesWithoutAnAmountAreNotExpenses() {
        assertTrue(LocalExpenseParser.parse("").isEmpty())
        assertTrue(LocalExpenseParser.parse("   ").isEmpty())
        assertTrue(LocalExpenseParser.parse("hello there").isEmpty())
        assertTrue(LocalExpenseParser.parse("um yeah you know").isEmpty())
    }

    @Test
    fun categoriesStayInTheKnownSet() {
        assertEquals("Food & drink", ExpenseCategory.normalize("food & drink"))
        assertEquals("Transport", ExpenseCategory.normalize("transport"))
        assertEquals("Transport", ExpenseCategory.infer("uber to the airport"))
        assertEquals("Health", ExpenseCategory.infer("pharmacy bill"))
        assertEquals("Shopping", ExpenseCategory.infer("amazon clothes"))
        assertEquals("Other", ExpenseCategory.infer("something else"))
        for (name in ExpenseCategory.all) {
            assertEquals(name, ExpenseCategory.normalize(name))
        }
    }

    @Test
    fun rupeeFormattingUsesIndianGrouping() {
        assertEquals("₹1,00,000.00", formatRupees(100_000.0))
        assertEquals("-₹250.50", formatRupees(-250.5))
    }
}

private data class Phrase(
    val spoken: String,
    val amount: Double,
    val title: String,
    val category: String,
)
