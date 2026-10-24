package `in`.akshaux.finflow.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import `in`.akshaux.finflow.MainActivity
import `in`.akshaux.finflow.R
import `in`.akshaux.finflow.data.FinFlowDatabase
import `in`.akshaux.finflow.data.ExpenseRepository
import `in`.akshaux.finflow.rupees
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class TodayWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val pending = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val start = ExpenseRepository.startOfDay()
                val dao = FinFlowDatabase.get(context).expenses()
                publish(context, dao.totalBetween(start, start + DAY), dao.countBetween(start, start + DAY))
            } finally {
                pending.finish()
            }
        }
    }

    companion object {
        private const val DAY = 24L * 60L * 60L * 1000L

        fun publish(context: Context, total: Double, count: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_today)
            views.setTextViewText(R.id.total, rupees(total))
            views.setTextViewText(
                R.id.count,
                if (count == 1) "1 expense today" else "$count expenses today",
            )
            val intent = Intent(context, MainActivity::class.java).apply {
                action = MainActivity.ACTION_START_CAPTURE
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val open = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_root, open)
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, TodayWidget::class.java))
            ids.forEach { manager.updateAppWidget(it, views) }
        }
    }
}
