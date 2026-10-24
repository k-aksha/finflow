package `in`.akshaux.finflow.data

import android.content.Context
import `in`.akshaux.finflow.parser.DraftExpense
import `in`.akshaux.finflow.widget.TodayWidget
import java.util.Calendar

class ExpenseRepository(private val context: Context) {
    private val dao = FinFlowDatabase.get(context).expenses()

    fun observeAll() = dao.observeAll()

    fun observeCount() = dao.observeCount()

    suspend fun save(drafts: List<DraftExpense>) {
        val records = drafts.mapNotNull { ExpenseEntity.from(it) }
        if (records.isEmpty()) error("Enter an amount such as 1500 or one lakh, and what it was for.")
        dao.insert(records)
        refreshWidget()
    }

    suspend fun erase() {
        dao.erase()
        refreshWidget()
    }

    private suspend fun refreshWidget() {
        val start = startOfDay()
        val end = start + DAY
        TodayWidget.publish(
            context,
            total = dao.totalBetween(start, end),
            count = dao.countBetween(start, end),
        )
    }

    companion object {
        private const val DAY = 24L * 60L * 60L * 1000L

        fun startOfDay(now: Long = System.currentTimeMillis()): Long {
            val calendar = Calendar.getInstance()
            calendar.timeInMillis = now
            calendar.set(Calendar.HOUR_OF_DAY, 0)
            calendar.set(Calendar.MINUTE, 0)
            calendar.set(Calendar.SECOND, 0)
            calendar.set(Calendar.MILLISECOND, 0)
            return calendar.timeInMillis
        }
    }
}
