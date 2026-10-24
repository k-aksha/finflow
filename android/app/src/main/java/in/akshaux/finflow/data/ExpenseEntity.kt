package `in`.akshaux.finflow.data

import androidx.room.Entity
import androidx.room.PrimaryKey
import `in`.akshaux.finflow.parser.DraftExpense
import java.util.UUID

@Entity(tableName = "expenses")
data class ExpenseEntity(
    @PrimaryKey val id: String,
    val title: String,
    val detail: String,
    val amount: Double,
    val category: String,
    val spokenOn: Long,
    val createdAt: Long,
) {
    companion object {
        fun from(draft: DraftExpense, spokenOn: Long = System.currentTimeMillis()): ExpenseEntity? {
            val title = draft.title.trim()
            if (!draft.amount.isFinite() || draft.amount <= 0 || title.isEmpty()) return null
            val detail = draft.detail.trim().ifEmpty { title }
            return ExpenseEntity(
                id = UUID.randomUUID().toString(),
                title = title.take(80),
                detail = detail.take(280),
                amount = draft.amount,
                category = draft.category,
                spokenOn = spokenOn,
                createdAt = System.currentTimeMillis(),
            )
        }
    }
}
