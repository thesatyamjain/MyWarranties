package com.thesoftwarelabs.mywarranties

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews

class WarrantyAppWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        private const val PREFS_NAME = "WarrantyWidgetPrefs"
        const val KEY_ACTIVE_COUNT = "active_count"
        const val KEY_NEXT_NAME = "next_name"
        const val KEY_NEXT_DAYS = "next_days"
        const val KEY_NEXT_SUBTITLE = "next_subtitle"

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, WarrantyAppWidgetProvider::class.java)
            val allIds = appWidgetManager.getAppWidgetIds(thisWidget)
            for (id in allIds) {
                updateAppWidget(context, appWidgetManager, id)
            }
        }

        private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val activeCount = prefs.getInt(KEY_ACTIVE_COUNT, 0)
            val nextName = prefs.getString(KEY_NEXT_NAME, "") ?: ""
            val nextDays = prefs.getInt(KEY_NEXT_DAYS, -1)
            val nextSubtitle = prefs.getString(KEY_NEXT_SUBTITLE, "") ?: ""

            val views = RemoteViews(context.packageName, R.layout.warranty_app_widget)

            // Header count badge
            views.setTextViewText(R.id.widget_active_badge, "$activeCount Active")

            if (nextName.isNotEmpty() && nextDays >= 0) {
                views.setTextViewText(R.id.widget_product_name, nextName)
                views.setTextViewText(R.id.widget_expiry_subtitle, nextSubtitle.ifEmpty { "Warranty expires soon" })

                val (pillText, textColor) = when {
                    nextDays == 0 -> Pair("Ends Today!", Color.parseColor("#EF4444"))
                    nextDays <= 7 -> Pair("$nextDays days left", Color.parseColor("#F59E0B"))
                    nextDays <= 30 -> Pair("$nextDays days left", Color.parseColor("#FBBF24"))
                    else -> Pair("$nextDays days left", Color.parseColor("#34D399"))
                }
                views.setTextViewText(R.id.widget_days_pill, pillText)
                views.setTextColor(R.id.widget_days_pill, textColor)
            } else {
                views.setTextViewText(R.id.widget_product_name, if (activeCount > 0) "All warranties safe" else "No warranties yet")
                views.setTextViewText(R.id.widget_expiry_subtitle, if (activeCount > 0) "Nothing expires soon" else "Tap to add or scan a bill")
                views.setTextViewText(R.id.widget_days_pill, if (activeCount > 0) "All Safe" else "+ Add Bill")
                views.setTextColor(R.id.widget_days_pill, Color.parseColor("#38BDF8"))
            }

            // Click action to open app
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
