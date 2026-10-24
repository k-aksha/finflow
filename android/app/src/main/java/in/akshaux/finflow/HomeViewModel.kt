package `in`.akshaux.finflow

import android.app.Application
import android.os.Handler
import android.os.Looper
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import `in`.akshaux.finflow.data.ExpenseRepository
import `in`.akshaux.finflow.parser.DraftExpense
import `in`.akshaux.finflow.parser.LocalExpenseParser
import `in`.akshaux.finflow.voice.DeviceSpeech
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

enum class CapturePhase {
    Idle, Listening, Analyzing, Done, Failed,
}

data class CaptureUi(
    val phase: CapturePhase = CapturePhase.Idle,
    val transcript: String = "",
    val message: String = "",
    val recoveryAmount: String = "",
    val recoveryTitle: String = "",
)

class HomeViewModel(application: Application) : AndroidViewModel(application) {
    private val repository = ExpenseRepository(application)
    private val speech = DeviceSpeech(application)
    private val main = Handler(Looper.getMainLooper())
    private val _ui = MutableStateFlow(CaptureUi())
    val ui: StateFlow<CaptureUi> = _ui

    init {
        speech.onPartial = { text -> update { it.copy(transcript = text) } }
        speech.onFinished = { text -> finishListening(text) }
        speech.onError = { message ->
            update { it.copy(phase = CapturePhase.Failed, message = message) }
        }
    }

    fun toggle() {
        val phase = _ui.value.phase
        if (phase == CapturePhase.Listening) {
            speech.stop()
            return
        }
        if (phase == CapturePhase.Analyzing) return
        update {
            it.copy(
                phase = CapturePhase.Listening,
                transcript = "",
                message = "",
                recoveryAmount = "",
                recoveryTitle = "",
            )
        }
        speech.start()
    }

    fun denyMicrophone() {
        update {
            it.copy(
                phase = CapturePhase.Failed,
                message = "Microphone access stays on this phone. Allow it to record an expense.",
            )
        }
    }

    fun updateTranscript(value: String) = update { it.copy(transcript = value) }
    fun updateAmount(value: String) = update { it.copy(recoveryAmount = value) }
    fun updateTitle(value: String) = update { it.copy(recoveryTitle = value) }

    fun retry() {
        val note = _ui.value.transcript.trim()
        if (note.isEmpty() || _ui.value.phase == CapturePhase.Analyzing) return
        saveParsed(note)
    }

    fun saveRecovery() {
        val amount = _ui.value.recoveryAmount.trim()
        val title = _ui.value.recoveryTitle.trim()
        val draft = LocalExpenseParser.recovered(amount, title)
        if (draft == null) {
            update {
                it.copy(
                    phase = CapturePhase.Failed,
                    message = "Enter an amount such as 1500 or one lakh, and what it was for.",
                )
            }
            return
        }
        persist(listOf(draft))
    }

    fun dismiss() {
        val phase = _ui.value.phase
        if (phase == CapturePhase.Listening || phase == CapturePhase.Analyzing) return
        update { CaptureUi() }
    }

    private fun finishListening(text: String) {
        val spoken = text.trim()
        update { it.copy(transcript = spoken) }
        if (spoken.isEmpty()) {
            update {
                it.copy(
                    phase = CapturePhase.Failed,
                    message = "I didn’t catch that. Tap the mic and say what you spent.",
                )
            }
            return
        }
        saveParsed(spoken)
    }

    private fun saveParsed(spoken: String) {
        update { it.copy(phase = CapturePhase.Analyzing, transcript = spoken) }
        val drafts = LocalExpenseParser.parse(spoken)
        if (drafts.isEmpty()) {
            update {
                it.copy(
                    phase = CapturePhase.Failed,
                    message = "I could not find an expense in that. Try naming the amount and what it was for.",
                )
            }
            return
        }
        persist(drafts)
    }

    private fun persist(drafts: List<DraftExpense>) {
        viewModelScope.launch {
            try {
                repository.save(drafts)
                update { it.copy(phase = CapturePhase.Done) }
                main.postDelayed({
                    if (_ui.value.phase == CapturePhase.Done) update { CaptureUi() }
                }, 1400)
            } catch (error: Exception) {
                update {
                    it.copy(
                        phase = CapturePhase.Failed,
                        message = error.message ?: "Couldn’t save that expense.",
                    )
                }
            }
        }
    }

    private fun update(block: (CaptureUi) -> CaptureUi) {
        _ui.value = block(_ui.value)
    }

    override fun onCleared() {
        speech.release()
    }
}
