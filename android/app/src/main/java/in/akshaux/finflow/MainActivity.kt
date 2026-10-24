package `in`.akshaux.finflow

import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.setValue
import `in`.akshaux.finflow.ui.FinFlowRoot
import `in`.akshaux.finflow.ui.FinFlowTheme

class MainActivity : ComponentActivity() {
    private var captureRequests by mutableIntStateOf(0)

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(0xFF111111.toInt()),
            navigationBarStyle = SystemBarStyle.dark(0xFF090909.toInt()),
        )
        super.onCreate(savedInstanceState)
        if (wantsCapture(intent)) captureRequests = 1
        setContent {
            FinFlowTheme {
                FinFlowRoot(captureRequests = captureRequests)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (wantsCapture(intent)) captureRequests += 1
    }

    companion object {
        const val ACTION_START_CAPTURE = "in.akshaux.finflow.START_CAPTURE"

        fun captureIntent(context: Context): Intent {
            return Intent(context, MainActivity::class.java).apply {
                action = ACTION_START_CAPTURE
            }
        }

        private fun wantsCapture(intent: Intent?): Boolean {
            return intent?.action == ACTION_START_CAPTURE
        }
    }
}
