package `in`.akshaux.finflow.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color

val Ink = Color(0xFF111111)
val InkBottom = Color(0xFF090909)
val Card = Color(0xFF1C1C1C)
val NavBar = Color(0xFF171717)
val Selected = Color(0xFF2E2E2E)
val Raised = Color(0xFF242424)
val Chip = Color(0xFF333333)
val Muted = Color.White.copy(alpha = 0.72f)

private val FinFlowScheme = darkColorScheme(
    primary = Color(0xFFE6E6E6),
    onPrimary = Ink,
    primaryContainer = Selected,
    onPrimaryContainer = Color.White,
    secondary = Selected,
    onSecondary = Color.White,
    secondaryContainer = Raised,
    onSecondaryContainer = Color.White,
    tertiary = Chip,
    onTertiary = Color.White,
    background = Ink,
    onBackground = Color.White,
    surface = Card,
    onSurface = Color.White,
    surfaceVariant = Raised,
    onSurfaceVariant = Muted,
    surfaceTint = Color.Transparent,
    outline = Color.White.copy(alpha = 0.12f),
    error = Color(0xFFB42318),
    onError = Color.White,
)

@Composable
fun FinFlowTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = FinFlowScheme, content = content)
}

@Composable
fun FinFlowBackground(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Box(
        modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(Ink, InkBottom))),
    ) {
        content()
    }
}
