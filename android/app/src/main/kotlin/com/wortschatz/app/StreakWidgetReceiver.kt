package com.wortschatz.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/// Streak-only widget: big counter plus a nudge when nothing was
/// studied today.
class StreakWidgetReceiver : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val streak = widgetData.getInt("streak", 0)
        val today = widgetData.getInt("today", 0)
        val message = if (today > 0) {
            "روز پشت سر هم"
        } else {
            "امروز انجام ندادی!"
        }
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.streak_widget).apply {
                setTextViewText(R.id.streak_count, streak.toString())
                setTextViewText(R.id.streak_msg, message)
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.streak_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
