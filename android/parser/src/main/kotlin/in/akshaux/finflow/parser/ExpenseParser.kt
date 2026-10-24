package `in`.akshaux.finflow.parser

data class DraftExpense(
    val title: String,
    val detail: String,
    val amount: Double,
    val category: String,
)

object ExpenseCategory {
    val all = listOf(
        "Food & drink",
        "Transport",
        "Shopping",
        "Bills",
        "Health",
        "Entertainment",
        "Other",
    )

    fun normalize(raw: String): String {
        val trimmed = raw.trim()
        return all.firstOrNull { it.equals(trimmed, ignoreCase = true) } ?: infer(trimmed)
    }

    fun infer(text: String): String {
        val value = text.lowercase()
        if (listOf("coffee", "biryani", "biriyani", "lunch", "dinner", "food", "tea", "snack").any { value.contains(it) }) {
            return "Food & drink"
        }
        if (listOf("petrol", "uber", "ola", "bus", "metro", "fuel", "cab").any { value.contains(it) }) {
            return "Transport"
        }
        if (listOf("medicine", "doctor", "pharmacy").any { value.contains(it) }) {
            return "Health"
        }
        if (listOf("movie", "game").any { value.contains(it) }) {
            return "Entertainment"
        }
        if (listOf("shop", "amazon", "clothes").any { value.contains(it) }) {
            return "Shopping"
        }
        if (listOf("bill", "rent", "recharge", "electric").any { value.contains(it) }) {
            return "Bills"
        }
        return "Other"
    }
}

object LocalExpenseParser {
    private val units = mapOf(
        "zero" to 0.0, "oh" to 0.0, "one" to 1.0, "two" to 2.0, "three" to 3.0, "four" to 4.0,
        "five" to 5.0, "six" to 6.0, "seven" to 7.0, "eight" to 8.0, "nine" to 9.0,
        "ten" to 10.0, "eleven" to 11.0, "twelve" to 12.0, "thirteen" to 13.0, "fourteen" to 14.0,
        "fifteen" to 15.0, "sixteen" to 16.0, "seventeen" to 17.0, "eighteen" to 18.0, "nineteen" to 19.0,
        "twenty" to 20.0, "thirty" to 30.0, "forty" to 40.0, "fifty" to 50.0,
        "sixty" to 60.0, "seventy" to 70.0, "eighty" to 80.0, "ninety" to 90.0,
    )

    private val scales = listOf(
        "crores" to 10_000_000.0, "crore" to 10_000_000.0,
        "lakhs" to 100_000.0, "lakh" to 100_000.0, "lacs" to 100_000.0, "lac" to 100_000.0, "lack" to 100_000.0,
        "thousand" to 1_000.0, "hundred" to 100.0,
    )

    private val rupeeWords = setOf("rupee", "rupees", "inr")
    private val connectors = setOf("for", "on", "towards")
    private val skipWords = setOf(
        "i", "me", "my", "we", "our", "spent", "spend", "spending", "paid", "pay", "paying",
        "bought", "buy", "got", "had", "have", "was", "were", "is", "the", "a", "an", "of",
        "to", "and", "today", "yesterday", "just", "about", "around", "roughly", "only",
        "please", "rupee", "rupees", "inr", "rs", "worth", "cost", "costs", "costing",
        "at", "from", "in", "total", "overall", "altogether",
    )

    private val fillerWords = setOf(
        "um", "umm", "uhm", "uh", "uhh", "hmm", "hm", "mm", "mmm", "erm", "er", "ah", "ahh", "eh",
        "like", "so", "well", "basically", "actually", "literally", "just",
        "kinda", "sorta", "okay", "ok", "yeah", "yea", "yep", "yup", "yes", "right", "please", "pls",
        "anyway", "honestly", "alright", "huh", "thanks", "thank",
    )

    private val fillerPhrases = listOf(
        listOf("kind", "of"),
        listOf("sort", "of"),
        listOf("you", "know"),
        listOf("i", "mean"),
        listOf("i", "guess"),
        listOf("you", "see"),
        listOf("thank", "you"),
        listOf("all", "right"),
        listOf("kind", "a"),
        listOf("sort", "a"),
    )

    fun parse(transcript: String): List<DraftExpense> {
        val words = stripFillers(tokenize(transcript))
        val matches = amounts(words)
        if (matches.isEmpty()) return emptyList()

        val drafts = matches.mapIndexed { index, match ->
            val previousEnd = if (index == 0) 0 else matches[index - 1].end
            val nextStart = if (index + 1 < matches.size) matches[index + 1].start else words.size
            val name = title(words, match, previousEnd, nextStart)
            DraftExpense(
                title = name,
                detail = name,
                amount = match.value,
                category = ExpenseCategory.infer(name),
            )
        }.toMutableList()

        if (drafts.size >= 2) {
            val parts = drafts.dropLast(1).sumOf { it.amount }
            if (kotlin.math.abs(parts - drafts.last().amount) < 0.5) {
                drafts.removeAt(drafts.lastIndex)
            }
        }
        return drafts
    }

    fun recovered(amountText: String, title: String): DraftExpense? {
        val phrase = if (title.isBlank()) "$amountText rupees" else "$amountText rupees for $title"
        val parsed = parse(phrase).firstOrNull()
        if (parsed != null && parsed.amount > 0) {
            val resolved = if (title.isBlank()) parsed.title else title.trim().replaceFirstChar { it.titlecase() }
            return DraftExpense(
                title = resolved,
                detail = resolved,
                amount = parsed.amount,
                category = ExpenseCategory.infer(resolved),
            )
        }
        val digits = amountText.replace(",", "").replace("₹", "").trim()
        val amount = digits.toDoubleOrNull()
        if (amount == null || !amount.isFinite() || amount <= 0) return null
        val resolved = if (title.isBlank()) "Expense" else title.trim().replaceFirstChar { it.titlecase() }
        return DraftExpense(resolved, resolved, amount, ExpenseCategory.infer(resolved))
    }

    private data class AmountMatch(val value: Double, val start: Int, val end: Int)
    private data class NumberParse(val value: Double, val end: Int, val strong: Boolean)

    private fun amounts(words: List<String>): List<AmountMatch> {
        val found = mutableListOf<AmountMatch>()
        var index = 0
        while (index < words.size) {
            if (rupeeWords.contains(words[index])) {
                val parsed = number(words, index + 1)
                if (parsed != null && !isCount(words, index + 1, parsed.end)) {
                    val end = pastRupee(parsed.end, words)
                    found += AmountMatch(parsed.value, index, end)
                    index = end
                    continue
                }
            }
            val parsed = number(words, index)
            if (parsed != null) {
                if (isCount(words, index, parsed.end)) {
                    index = parsed.end
                    continue
                }
                val end = pastRupee(parsed.end, words)
                val followedByPurpose = end < words.size && connectors.contains(words[end])
                if (parsed.strong || followedByPurpose || end > parsed.end) {
                    found += AmountMatch(parsed.value, index, end)
                    index = end
                    continue
                }
            }
            index += 1
        }
        return found
    }

    private fun number(words: List<String>, start: Int): NumberParse? {
        var index = start
        var total = 0.0
        var current = 0.0
        var consumed = false
        var strong = false
        var lastScale = 0.0

        while (index < words.size) {
            val word = words[index]
            if (word == "and") {
                val upcoming = words.getOrElse(index + 1) { "" }
                val halfAfterArticle = (upcoming == "a" || upcoming == "an") &&
                    index + 2 < words.size && words[index + 2] == "half"
                if (current == 0.0 && lastScale > 0 && (upcoming == "half" || halfAfterArticle)) {
                    total += lastScale / 2
                    index += if (halfAfterArticle) 3 else 2
                    consumed = true
                    continue
                }
                if (upcoming == "a" || upcoming == "an" || upcoming == "half" || units.containsKey(upcoming) || decimal(upcoming) != null) {
                    index += 1
                    continue
                }
                break
            }
            if (word == "a" || word == "an") {
                val upcoming = words.getOrElse(index + 1) { "" }
                if (upcoming == "half") {
                    current += 0.5
                    consumed = true
                    index += 2
                    continue
                }
                if (scale(upcoming) != null) {
                    current += 1
                    consumed = true
                    index += 1
                    continue
                }
                break
            }
            if (word == "half") {
                current += 0.5
                consumed = true
                index += 1
                continue
            }
            if (word == "point" || word == "decimal") {
                val fraction = StringBuilder()
                var cursor = index + 1
                while (cursor < words.size && fraction.length < 2) {
                    val digit = singleDigit(words[cursor]) ?: break
                    fraction.append(digit)
                    cursor += 1
                }
                val value = if (fraction.isEmpty()) null else "0.$fraction".toDoubleOrNull()
                if (value != null) {
                    current = kotlin.math.floor(current) + value
                    consumed = true
                    index = cursor
                    continue
                }
                break
            }
            val glued = gluedScale(word) ?: decimal(word)
            if (glued != null) {
                if (current == 0.0 && total > 0) break
                current += glued
                consumed = true
                strong = true
                index += 1
                continue
            }
            val unit = units[word]
            if (unit != null) {
                current += unit
                consumed = true
                if (unit >= 20) strong = true
                index += 1
                continue
            }
            val factor = scale(word)
            if (factor != null) {
                if (current == 0.0) current = 1.0
                if (factor == 100.0) {
                    current *= factor
                } else {
                    total += current * factor
                    current = 0.0
                    lastScale = factor
                }
                consumed = true
                strong = true
                index += 1
                continue
            }
            break
        }

        total += current
        if (!consumed || total <= 0 || index <= start) return null
        return NumberParse(total, index, strong)
    }

    private fun title(words: List<String>, match: AmountMatch, previousEnd: Int, nextStart: Int): String {
        if (match.end < words.size && connectors.contains(words[match.end])) {
            val spoken = nameWords(words.subList(match.end + 1, nextStart))
            if (spoken.isNotEmpty()) return spoken
        }
        val spoken = nameWords(words.subList(previousEnd, match.start))
        return spoken.ifEmpty { "Expense" }
    }

    private fun nameWords(words: List<String>): String {
        val kept = mutableListOf<String>()
        var index = 0
        while (index < words.size && kept.size < 8) {
            val word = words[index]
            if (fillerWords.contains(word)) {
                index += 1
                continue
            }
            val parsed = number(words, index)
            if (parsed != null && parsed.end > index) {
                kept += formatCount(parsed.value)
                index = parsed.end
                continue
            }
            if (skipWords.contains(word) || connectors.contains(word) || scale(word) != null || rupeeWords.contains(word)) {
                index += 1
                continue
            }
            kept += word
            index += 1
        }
        if (kept.isEmpty()) return ""
        return kept.joinToString(" ") { token -> displayToken(token) }
    }

    private fun isCount(words: List<String>, start: Int, end: Int): Boolean {
        if (end >= words.size || !isPurchaseWord(words[end])) return false
        return hasMoneyAmount(words, start, end)
    }

    private fun hasMoneyAmount(words: List<String>, skipStart: Int, skipEnd: Int): Boolean {
        var index = 0
        while (index < words.size) {
            if (index >= skipStart && index < skipEnd) {
                index = skipEnd
                continue
            }
            val parsed = number(words, index)
            if (parsed != null && parsed.end > index) {
                if (isMoney(words, parsed)) return true
                index = parsed.end
                continue
            }
            index += 1
        }
        return false
    }

    private fun isMoney(words: List<String>, parsed: NumberParse): Boolean {
        val end = pastRupee(parsed.end, words)
        if (end > parsed.end) return true
        if (end < words.size && connectors.contains(words[end])) return true
        if (parsed.strong && (parsed.end >= words.size || !isPurchaseWord(words[parsed.end]))) return true
        return false
    }

    private fun isPurchaseWord(word: String): Boolean {
        if (fillerWords.contains(word) || skipWords.contains(word) || connectors.contains(word) || rupeeWords.contains(word)) {
            return false
        }
        if (units.containsKey(word) || scale(word) != null || decimal(word) != null) return false
        if (word == "half" || word == "point" || word == "decimal") return false
        return true
    }

    private fun formatCount(value: Double): String {
        val nearest = kotlin.math.round(value)
        if (kotlin.math.abs(value - nearest) < 0.001) return nearest.toLong().toString()
        return value.toString()
    }

    private fun displayToken(token: String): String {
        val first = token.firstOrNull() ?: return token
        if (first.isDigit()) return token
        return token.replaceFirstChar { it.titlecase() }
    }

    private fun stripFillers(words: List<String>): List<String> {
        val kept = mutableListOf<String>()
        var index = 0
        while (index < words.size) {
            val phrase = fillerPhrases.firstOrNull { candidate ->
                index + candidate.size <= words.size && words.subList(index, index + candidate.size) == candidate
            }
            if (phrase != null) {
                index += phrase.size
                continue
            }
            if (fillerWords.contains(words[index])) {
                index += 1
                continue
            }
            kept += words[index]
            index += 1
        }
        return kept
    }

    private fun pastRupee(index: Int, words: List<String>): Int {
        if (index < words.size && rupeeWords.contains(words[index])) return index + 1
        return index
    }

    private fun scale(word: String): Double? = scales.firstOrNull { it.first == word }?.second

    private fun decimal(word: String): Double? {
        val cleaned = word.replace(",", "")
        if (cleaned.none { it.isDigit() }) return null
        return cleaned.toDoubleOrNull()?.takeIf { it >= 0 }
    }

    private fun singleDigit(word: String): Char? {
        val unit = units[word]
        if (unit != null && unit < 10 && unit == kotlin.math.floor(unit)) {
            return unit.toInt().digitToChar()
        }
        if (word.length == 1 && word[0].isDigit()) return word[0]
        return null
    }

    private fun gluedScale(word: String): Double? {
        for ((suffix, factor) in scales) {
            if (word.endsWith(suffix) && word.length > suffix.length) {
                val head = word.dropLast(suffix.length)
                val value = head.toDoubleOrNull()
                if (value != null) return value * factor
            }
        }
        return null
    }

    private fun tokenize(transcript: String): List<String> {
        var text = transcript.lowercase().replace("₹", " rupees ")
        text = Regex("""(?i)\brs\.?(?=\d)""").replace(text, " rupees ")
        text = Regex("""(?i)\brs\.?\b""").replace(text, " rupees ")
        text = Regex("""(\d),(?=\d)""").replace(text, "$1")
        val words = mutableListOf<String>()
        val current = StringBuilder()
        fun flush() {
            val token = current.toString().trim('.')
            if (token.isNotEmpty()) words += token
            current.clear()
        }
        for (character in text) {
            if (character.isLetter() || character.isDigit() || character == '.') {
                current.append(character)
            } else {
                flush()
            }
        }
        flush()
        return words
    }
}
