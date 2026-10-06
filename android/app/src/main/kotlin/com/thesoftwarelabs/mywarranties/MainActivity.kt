package com.thesoftwarelabs.mywarranties

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val WIDGET_CHANNEL = "com.thesoftwarelabs.mywarranties/widget"
    private val SHARE_CHANNEL = "com.thesoftwarelabs.mywarranties/share"
    private val PREFS_NAME = "WarrantyWidgetPrefs"

    private var initialSharedFiles = mutableListOf<String>()
    private var shareMethodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Widget Data Channel
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

        // Incoming Share Channel (WhatsApp, Gallery, Files, etc.)
        shareMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                if (call.method == "getInitialSharedFiles") {
                    val files = ArrayList(initialSharedFiles)
                    initialSharedFiles.clear()
                    result.success(files)
                } else {
                    result.notImplemented()
                }
            }
        }

        // Process startup intent if launched with shared file
        val files = handleSendIntent(intent)
        if (files.isNotEmpty()) {
            initialSharedFiles.addAll(files)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val files = handleSendIntent(intent)
        if (files.isNotEmpty()) {
            shareMethodChannel?.invokeMethod("onFilesShared", files)
        }
    }

    private fun handleSendIntent(intent: Intent?): List<String> {
        if (intent == null) return emptyList()
        val action = intent.action ?: return emptyList()
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) return emptyList()

        val type = intent.type ?: ""
        val uris = mutableListOf<Uri>()

        if (Intent.ACTION_SEND == action) {
            val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_STREAM)
            }
            if (uri != null) uris.add(uri)
        } else if (Intent.ACTION_SEND_MULTIPLE == action) {
            val list = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
            }
            if (list != null) uris.addAll(list)
        }

        val resultPaths = mutableListOf<String>()
        for (uri in uris) {
            try {
                val ext = if (type.contains("pdf", ignoreCase = true)) ".pdf" else ".jpg"
                val tempFile = File(cacheDir, "shared_bill_${System.currentTimeMillis()}_${resultPaths.size}$ext")
                contentResolver.openInputStream(uri)?.use { input ->
                    tempFile.outputStream().use { output ->
                        input.copyTo(output)
                    }
                }
                if (tempFile.exists() && tempFile.length() > 0) {
                    resultPaths.add(tempFile.absolutePath)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        return resultPaths
    }
}
