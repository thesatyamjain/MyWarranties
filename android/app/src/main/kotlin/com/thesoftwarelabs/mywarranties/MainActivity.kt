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

        // Native Package Installer Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.thesoftwarelabs.mywarranties/installer").setMethodCallHandler { call, result ->
            if (call.method == "installApk") {
                val filePath = call.argument<String>("filePath")
                if (filePath.isNullOrEmpty()) {
                    result.error("INVALID_PATH", "File path is empty", null)
                    return@setMethodCallHandler
                }

                try {
                    val file = File(filePath)
                    if (!file.exists()) {
                        result.error("NOT_FOUND", "File does not exist: $filePath", null)
                        return@setMethodCallHandler
                    }

                    val apkUri: Uri = androidx.core.content.FileProvider.getUriForFile(
                        context,
                        "${context.packageName}.fileprovider",
                        file
                    )

                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(apkUri, "application/vnd.android.package-archive")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }

                    context.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("INSTALL_ERROR", e.message, null)
                }
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
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE && action != Intent.ACTION_VIEW) {
            return emptyList()
        }

        val type = intent.type ?: ""
        val uris = mutableListOf<Uri>()

        if (Intent.ACTION_VIEW == action) {
            intent.data?.let { uris.add(it) }
        } else if (Intent.ACTION_SEND == action) {
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
                var ext = if (type.contains("pdf", ignoreCase = true)) ".pdf" else ".jpg"
                val uriString = uri.toString().lowercase()
                val pathString = (uri.path ?: "").lowercase()
                if (uriString.endsWith(".mywarranty") || pathString.endsWith(".mywarranty")) {
                    ext = ".mywarranty"
                }

                val tempFile = File(cacheDir, "shared_warranty_${System.currentTimeMillis()}_${resultPaths.size}$ext")
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
