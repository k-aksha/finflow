package `in`.akshaux.finflow.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.ReceiptLong
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.airbnb.lottie.compose.LottieAnimation
import com.airbnb.lottie.compose.LottieCompositionSpec
import com.airbnb.lottie.compose.animateLottieCompositionAsState
import com.airbnb.lottie.compose.rememberLottieComposition

private enum class Tab(val label: String, val icon: ImageVector) {
    Home("Home", Icons.Rounded.Home),
    Expenses("Expenses", Icons.Rounded.ReceiptLong),
    Settings("Settings", Icons.Rounded.Settings),
}

@Composable
fun FinFlowRoot(captureRequests: Int) {
    val context = LocalContext.current
    val prefs = remember { context.getSharedPreferences("finflow", android.content.Context.MODE_PRIVATE) }
    var entered by remember { mutableStateOf(prefs.getBoolean("hasEntered", false)) }
    var showSplash by remember { mutableStateOf(captureRequests == 0) }
    var tab by remember { mutableStateOf(Tab.Home) }
    var startToken by remember { mutableIntStateOf(0) }

    LaunchedEffect(captureRequests) {
        if (captureRequests > 0) {
            showSplash = false
            tab = Tab.Home
            if (entered) startToken = captureRequests
        }
    }

    if (showSplash) {
        Splash { showSplash = false }
        return
    }
    if (!entered) {
        WelcomeScreen {
            prefs.edit().putBoolean("hasEntered", true).apply()
            entered = true
            if (captureRequests > 0) startToken = captureRequests
        }
        return
    }

    Scaffold(
        containerColor = Ink,
        bottomBar = {
            Row(
                Modifier
                    .padding(horizontal = 28.dp, vertical = 16.dp)
                    .background(NavBar, RoundedCornerShape(28.dp))
                    .padding(6.dp),
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Tab.entries.forEach { item ->
                    val selected = tab == item
                    androidx.compose.material3.TextButton(
                        onClick = { tab = item },
                        modifier = Modifier
                            .weight(1f)
                            .background(if (selected) Selected else Color.Transparent, RoundedCornerShape(22.dp)),
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Icon(item.icon, contentDescription = item.label, tint = Color.White)
                            if (selected) Text(item.label, color = Color.White, fontSize = 12.sp)
                        }
                    }
                }
            }
        },
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding)) {
            when (tab) {
                Tab.Home -> HomeScreen(startToken)
                Tab.Expenses -> ExpensesScreen()
                Tab.Settings -> SettingsScreen()
            }
        }
    }
}

@Composable
private fun Splash(onFinished: () -> Unit) {
    val composition by rememberLottieComposition(LottieCompositionSpec.Asset("Splash.json"))
    val progress by animateLottieCompositionAsState(composition, iterations = 1)
    LaunchedEffect(progress) {
        if (progress == 1f) onFinished()
    }
    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(5_000)
        onFinished()
    }
    FinFlowBackground {
        LottieAnimation(composition = composition, progress = { progress }, modifier = Modifier.fillMaxSize())
    }
}
