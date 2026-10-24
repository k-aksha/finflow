package `in`.akshaux.finflow.ui

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Mic
import androidx.compose.material.icons.rounded.Stop
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import android.content.pm.PackageManager
import com.airbnb.lottie.compose.LottieAnimation
import com.airbnb.lottie.compose.LottieCompositionSpec
import com.airbnb.lottie.compose.LottieConstants
import com.airbnb.lottie.compose.rememberLottieComposition
import `in`.akshaux.finflow.CapturePhase
import `in`.akshaux.finflow.HomeViewModel

@Composable
fun HomeScreen(startToken: Int, model: HomeViewModel = viewModel()) {
    val ui by model.ui.collectAsState()
    val context = LocalContext.current
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) model.toggle() else model.denyMicrophone()
    }
    LaunchedEffect(startToken) {
        if (startToken > 0) begin(context, model, permission)
    }

    val animation = when (ui.phase) {
        CapturePhase.Listening -> "CharacterListening.json"
        CapturePhase.Analyzing, CapturePhase.Failed -> "CharacterAnalyzing.json"
        CapturePhase.Done -> "CharacterDone.json"
        CapturePhase.Idle -> "CharacterHome.json"
    }
    val composition by rememberLottieComposition(LottieCompositionSpec.Asset(animation))

    FinFlowBackground {
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 28.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.height(if (ui.phase == CapturePhase.Idle) 36.dp else 12.dp))
            LottieAnimation(
                composition = composition,
                iterations = LottieConstants.IterateForever,
                modifier = Modifier.height(220.dp),
            )
            Text(
                status(ui.phase),
                color = Color.White,
                fontSize = 14.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 12.dp),
            )
            if (ui.phase == CapturePhase.Failed) {
                BasicTextField(
                    value = ui.transcript,
                    onValueChange = model::updateTranscript,
                    textStyle = TextStyle(color = Color.White, fontSize = 15.sp),
                    cursorBrush = SolidColor(Color.White),
                    modifier = Modifier
                        .padding(top = 18.dp)
                        .fillMaxWidth()
                        .height(96.dp)
                        .clip(RoundedCornerShape(24.dp))
                        .background(Card)
                        .padding(18.dp),
                )
            } else if (ui.phase != CapturePhase.Idle) {
                Text(
                    ui.transcript.ifBlank { "Transcription goes here..." },
                    color = if (ui.transcript.isBlank()) Color.White.copy(alpha = 0.4f) else Color.White,
                    fontSize = 15.sp,
                    modifier = Modifier
                        .padding(top = 18.dp)
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(24.dp))
                        .background(Card)
                        .padding(18.dp),
                )
            }
            if (ui.phase == CapturePhase.Failed) {
                Text(ui.message, color = Muted, fontSize = 13.sp, modifier = Modifier.padding(top = 14.dp))
                Field("Amount, such as 1500 or one lakh", ui.recoveryAmount, model::updateAmount)
                Field("What it was for", ui.recoveryTitle, model::updateTitle)
                Button(
                    onClick = model::saveRecovery,
                    enabled = ui.recoveryAmount.isNotBlank(),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 12.dp)
                        .height(48.dp),
                    shape = RoundedCornerShape(24.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Chip, contentColor = Color.White),
                ) {
                    Text("Save this expense")
                }
                Row(Modifier.padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    TextButton(onClick = model::retry, enabled = ui.transcript.isNotBlank()) {
                        Text("Analyze again", color = Color.White)
                    }
                    TextButton(onClick = model::dismiss) {
                        Text("Dismiss", color = Color.White)
                    }
                }
            }
            Spacer(Modifier.height(24.dp))
            Box(
                Modifier
                    .size(88.dp)
                    .clip(CircleShape)
                    .background(Selected)
                    .padding(4.dp),
                contentAlignment = Alignment.Center,
            ) {
                androidx.compose.material3.IconButton(
                    onClick = { begin(context, model, permission) },
                    enabled = ui.phase != CapturePhase.Analyzing,
                    modifier = Modifier.fillMaxSize(),
                ) {
                    androidx.compose.material3.Icon(
                        imageVector = if (ui.phase == CapturePhase.Listening) Icons.Rounded.Stop else Icons.Rounded.Mic,
                        contentDescription = if (ui.phase == CapturePhase.Listening) "Stop" else "Tap to speak expenses",
                        tint = Color.White,
                        modifier = Modifier.size(36.dp),
                    )
                }
            }
            Spacer(Modifier.height(28.dp))
        }
    }
}

private fun begin(
    context: android.content.Context,
    model: HomeViewModel,
    permission: androidx.activity.result.ActivityResultLauncher<String>,
) {
    val allowed = ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
        PackageManager.PERMISSION_GRANTED
    if (allowed || model.ui.value.phase == CapturePhase.Listening) model.toggle()
    else permission.launch(Manifest.permission.RECORD_AUDIO)
}

private fun status(phase: CapturePhase): String = when (phase) {
    CapturePhase.Idle -> "Tap to speak your expenses, then tap again to finish"
    CapturePhase.Listening -> "I am listening..."
    CapturePhase.Analyzing -> "Give me a moment.. analyzing"
    CapturePhase.Done -> "It’s Done.."
    CapturePhase.Failed -> "Couldn’t analyze that"
}

@Composable
private fun Field(hint: String, value: String, onChange: (String) -> Unit) {
    BasicTextField(
        value = value,
        onValueChange = onChange,
        textStyle = TextStyle(color = Color.White, fontSize = 16.sp),
        cursorBrush = SolidColor(Color.White),
        singleLine = true,
        modifier = Modifier
            .padding(top = 10.dp)
            .fillMaxWidth()
            .height(48.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(Color.White.copy(alpha = 0.08f))
            .padding(horizontal = 14.dp, vertical = 14.dp),
        decorationBox = { inner ->
            if (value.isEmpty()) Text(hint, color = Color.White.copy(alpha = 0.4f), fontSize = 16.sp)
            inner()
        },
    )
}
