package com.wortschatz.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class WortschatzWidgetReceiver : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.wortschatz_widget).apply {
                setTextViewText(R.id.widget_word, widgetData.getString("word", "—"))
                setTextViewText(R.id.widget_meaning, widgetData.getString("meaning", ""))
                setTextViewText(R.id.widget_stats, widgetData.getString("stats", ""))
                val today = widgetData.getInt("today", 0)
                val goal = widgetData.getInt("goal", 10).coerceAtLeast(1)
                setTextViewText(R.id.widget_goal_text, "هدف امروز: $today از $goal")
                setProgressBar(R.id.widget_goal_bar, goal, today.coerceAtMost(goal), false)
                val openApp = HomeWidgetLaunchIntent.getActivity(
                    context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.widget_root, openApp)
                // "Review" button deep-links straight into the Leitner tab.
                val openReview = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("wortschatz://review"))
                setOnClickPendingIntent(R.id.widget_review, openReview)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
