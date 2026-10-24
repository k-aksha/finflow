package `in`.akshaux.finflow.ui

import android.app.Application
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import `in`.akshaux.finflow.data.ExpenseRepository
import kotlinx.coroutines.launch

class SettingsViewModel(application: Application) : AndroidViewModel(application) {
    private val repository = ExpenseRepository(application)
    val saved = repository.observeCount()

    fun erase() {
        viewModelScope.launch { repository.erase() }
    }
}

@Composable
fun SettingsScreen(model: SettingsViewModel = viewModel()) {
    val count by model.saved.collectAsState(initial = 0)
    var confirm by remember { mutableStateOf(false) }
    FinFlowBackground {
        Column(Modifier.fillMaxSize().padding(28.dp)) {
            Text("On this device", color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(22.dp))
            LabelBlock(
                "Speech",
                "Transcribed on this phone. Tap the mic to start, then tap again to finish. FinFlow does not send the recording anywhere.",
            )
            LabelBlock(
                "Storage",
                "$count expenses saved on this phone. They stay separate from your iPhone.",
            )
            LabelBlock(
                "From anywhere",
                "Add the FinFlow widget to the home screen, or long-press the app icon and choose Log expense.",
            )
            Spacer(Modifier.height(12.dp))
            if (confirm) {
                Text("Erase every expense stored on this phone?", color = Color.White)
                Button(
                    onClick = {
                        model.erase()
                        confirm = false
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFB42318)),
                    modifier = Modifier.padding(top = 8.dp),
                ) { Text("Erase") }
            } else {
                Button(
                    onClick = { confirm = true },
                    enabled = count > 0,
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFB42318)),
                ) { Text("Erase all expenses") }
            }
        }
    }
}

@Composable
private fun LabelBlock(title: String, value: String) {
    Text(title, color = Muted, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
    Text(value, color = Color.White, fontSize = 16.sp, modifier = Modifier.padding(top = 4.dp, bottom = 18.dp))
}
