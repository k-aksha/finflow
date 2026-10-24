package `in`.akshaux.finflow.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import android.app.Application
import `in`.akshaux.finflow.data.ExpenseEntity
import `in`.akshaux.finflow.data.ExpenseRepository
import `in`.akshaux.finflow.rupees
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class ExpensesViewModel(application: Application) : AndroidViewModel(application) {
    val days = ExpenseRepository(application).observeAll()
        .map { expenses ->
            expenses.groupBy { ExpenseRepository.startOfDay(it.spokenOn) }
                .toSortedMap(compareByDescending { it })
                .map { (day, items) -> DayGroup(day, items) }
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
}

data class DayGroup(val day: Long, val items: List<ExpenseEntity>)

@Composable
fun ExpensesScreen(model: ExpensesViewModel = viewModel()) {
    val days by model.days.collectAsState()
    FinFlowBackground {
        if (days.isEmpty()) {
            Column(Modifier.fillMaxSize().padding(28.dp), verticalArrangement = Arrangement.Center) {
                Text("No expenses yet", color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.SemiBold)
                Text(
                    "Tap the mic and say what you spent.",
                    color = Muted,
                    modifier = Modifier.padding(top = 8.dp),
                )
            }
        } else {
            LazyColumn(Modifier.fillMaxSize().padding(horizontal = 20.dp)) {
                item { Spacer(Modifier.height(24.dp)) }
                days.forEach { group ->
                    item(key = group.day) {
                        Row(
                            Modifier.fillMaxWidth().padding(top = 18.dp, bottom = 8.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                        ) {
                            Text(dayLabel(group.day), color = Color.White, fontWeight = FontWeight.SemiBold)
                            Text(rupees(group.items.sumOf { it.amount }), color = Color.White)
                        }
                    }
                    items(group.items, key = { it.id }) { expense ->
                        Column(
                            Modifier
                                .fillMaxWidth()
                                .padding(bottom = 8.dp)
                                .clip(RoundedCornerShape(16.dp))
                                .background(Card)
                                .padding(14.dp),
                        ) {
                            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                Text(expense.title, color = Color.White, fontWeight = FontWeight.Medium)
                                Text(rupees(expense.amount), color = Color.White)
                            }
                            Text(
                                expense.category,
                                color = Color.White,
                                fontSize = 11.sp,
                                modifier = Modifier
                                    .padding(top = 8.dp)
                                    .clip(RoundedCornerShape(50))
                                    .background(Chip)
                                    .padding(horizontal = 8.dp, vertical = 4.dp),
                            )
                        }
                    }
                }
                item { Spacer(Modifier.height(24.dp)) }
            }
        }
    }
}

private fun dayLabel(day: Long): String {
    val format = SimpleDateFormat("EEE, d MMM", Locale("en", "IN"))
    return format.format(Date(day))
}
