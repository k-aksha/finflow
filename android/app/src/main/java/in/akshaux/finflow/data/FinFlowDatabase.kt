package `in`.akshaux.finflow.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

@Database(entities = [ExpenseEntity::class], version = 1, exportSchema = false)
abstract class FinFlowDatabase : RoomDatabase() {
    abstract fun expenses(): ExpenseDao

    companion object {
        @Volatile private var instance: FinFlowDatabase? = null

        fun get(context: Context): FinFlowDatabase {
            return instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder(
                    context.applicationContext,
                    FinFlowDatabase::class.java,
                    "finflow.db",
                ).build().also { instance = it }
            }
        }
    }
}
