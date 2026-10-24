package `in`.akshaux.finflow.parser

import java.util.Locale
import kotlin.math.abs

fun formatRupees(amount: Double): String {
    val negative = amount < 0
    val raw = String.format(Locale.US, "%.2f", abs(amount))
    val whole = raw.substringBefore(".")
    val fraction = raw.substringAfter(".")
    val grouped = if (whole.length <= 3) {
        whole
    } else {
        val head = whole.dropLast(3)
        val tail = whole.takeLast(3)
        val groups = ArrayDeque<String>()
        var index = head.length
        while (index > 0) {
            val start = maxOf(0, index - 2)
            groups.addFirst(head.substring(start, index))
            index = start
        }
        groups.joinToString(",") + "," + tail
    }
    return (if (negative) "-" else "") + "₹" + grouped + "." + fraction
}
