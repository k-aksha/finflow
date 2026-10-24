package `in`.akshaux.finflow.voice

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer

class DeviceSpeech(context: Context) {
    private val appContext = context.applicationContext
    private val main = Handler(Looper.getMainLooper())
    private var recognizer: SpeechRecognizer? = null
    private var latest = ""
    private var stopping = false

    var onPartial: (String) -> Unit = {}
    var onFinished: (String) -> Unit = {}
    var onError: (String) -> Unit = {}

    fun start() {
        main.post {
            if (!SpeechRecognizer.isRecognitionAvailable(appContext)) {
                onError("On-device speech isn’t available on this phone. Type the amount below.")
                return@post
            }
            latest = ""
            stopping = false
            recognizer?.destroy()
            val speech = SpeechRecognizer.createSpeechRecognizer(appContext)
            speech.setRecognitionListener(listener)
            recognizer = speech
            speech.startListening(listenIntent())
        }
    }

    fun stop() {
        main.post {
            stopping = true
            recognizer?.stopListening()
        }
    }

    fun release() {
        main.post {
            recognizer?.destroy()
            recognizer = null
        }
    }

    private fun listenIntent(): Intent {
        return Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-IN")
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }
    }

    private val listener = object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) = Unit
        override fun onBeginningOfSpeech() = Unit
        override fun onRmsChanged(rmsdB: Float) = Unit
        override fun onBufferReceived(buffer: ByteArray?) = Unit
        override fun onEndOfSpeech() = Unit
        override fun onEvent(eventType: Int, params: Bundle?) = Unit

        override fun onPartialResults(partialResults: Bundle?) {
            val text = partialResults.bestText()
            if (text.isNotBlank()) {
                latest = text
                onPartial(text)
            }
        }

        override fun onResults(results: Bundle?) {
            val text = results.bestText().ifBlank { latest }
            latest = text
            onFinished(text)
        }

        override fun onError(error: Int) {
            if (stopping && latest.isNotBlank()) {
                onFinished(latest)
                return
            }
            onError(message(error))
        }
    }

    private fun Bundle?.bestText(): String {
        return this?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty()
    }

    private fun message(error: Int): String {
        return when (error) {
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS ->
                "Microphone access stays on this phone. Allow it to record an expense."
            SpeechRecognizer.ERROR_NETWORK, SpeechRecognizer.ERROR_NETWORK_TIMEOUT, SpeechRecognizer.ERROR_SERVER ->
                "On-device speech isn’t available right now. Type the amount below."
            SpeechRecognizer.ERROR_NO_MATCH, SpeechRecognizer.ERROR_SPEECH_TIMEOUT ->
                "I didn’t catch that. Tap the mic and say what you spent."
            else -> "I didn’t catch that. Tap the mic and say what you spent."
        }
    }
}
