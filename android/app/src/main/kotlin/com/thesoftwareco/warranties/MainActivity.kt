package com.thesoftwareco.warranties

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val WIDGET_CHANNEL = "com.thesoftwareco.warranties/widget"
    private val PREFS_NAME = "WarrantyWidgetPrefs"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "updateWidgetData") {
                val activeCount = (call.argument<Number>("activeCount") ?: 0).toInt()
                val nextName = call.argument<String>("nextName") ?: ""
                val nextDays = (call.argument<Number>("nextDays") ?: -1).toInt()
                val nextSubtitle = call.argument<String>("nextSubtitle") ?: ""

                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                prefs.edit().apply {
                    putInt(WarrantyAppWidgetProvider.KEY_ACTIVE_COUNT, activeCount)
                    putString(WarrantyAppWidgetProvider.KEY_NEXT_NAME, nextName)
                    putInt(WarrantyAppWidgetProvider.KEY_NEXT_DAYS, nextDays)
                    putString(WarrantyAppWidgetProvider.KEY_NEXT_SUBTITLE, nextSubtitle)
                    apply()
                }

                WarrantyAppWidgetProvider.updateAllWidgets(context)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }
}
