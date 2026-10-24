package `in`.akshaux.finflow.data

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface ExpenseDao {
    @Query("SELECT * FROM expenses ORDER BY spokenOn DESC, createdAt DESC")
    fun observeAll(): Flow<List<ExpenseEntity>>

    @Query("SELECT COUNT(*) FROM expenses")
    fun observeCount(): Flow<Int>

    @Query("SELECT COALESCE(SUM(amount), 0) FROM expenses WHERE spokenOn >= :start AND spokenOn < :end")
    suspend fun totalBetween(start: Long, end: Long): Double

    @Query("SELECT COUNT(*) FROM expenses WHERE spokenOn >= :start AND spokenOn < :end")
    suspend fun countBetween(start: Long, end: Long): Int

    @Insert
    suspend fun insert(expenses: List<ExpenseEntity>)

    @Query("DELETE FROM expenses")
    suspend fun erase()
}
