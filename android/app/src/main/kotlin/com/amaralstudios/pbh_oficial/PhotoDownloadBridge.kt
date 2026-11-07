package com.amaralstudios.pbh_oficial

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class PhotoDownloadBridge(private val activity: Activity) {
    private val executor = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null
    private var closed = false
    private val requestCode = 46318

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "save") { result.notImplemented(); return }
        if (pending != null || closed) { result.error("BUSY", "Aguarde o download atual.", null); return }
        val bytes = call.argument<ByteArray>("bytes")
        val mime = call.argument<String>("mime")
        val name = call.argument<String>("name")
        if (bytes == null || bytes.isEmpty() || bytes.size > 10 * 1024 * 1024 ||
            mime !in listOf("image/jpeg", "image/png", "image/webp", "image/gif") ||
            name == null || !name.matches(Regex("pbh-foto-[0-9]+\\.(jpg|png|webp|gif)"))) {
            result.error("INVALID_IMAGE", "Foto inválida.", null); return
        }
        pending = result
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            executor.execute {
                var uri: Uri? = null
                try {
                    val resolver = activity.contentResolver
                    val values = ContentValues().apply {
                        put(MediaStore.Images.Media.DISPLAY_NAME, name)
                        put(MediaStore.Images.Media.MIME_TYPE, mime)
                        put(MediaStore.Images.Media.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/PBH")
                        put(MediaStore.Images.Media.IS_PENDING, 1)
                    }
                    uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values) ?: error("No media destination")
                    resolver.openOutputStream(uri)?.use { it.write(bytes) } ?: error("Cannot write image")
                    resolver.update(uri, ContentValues().apply { put(MediaStore.Images.Media.IS_PENDING, 0) }, null, null)
                    finish(true)
                } catch (_: Exception) {
                    uri?.let { try { activity.contentResolver.delete(it, null, null) } catch (_: Exception) {} }
                    finishError()
                }
            }
        } else {
            pendingBytes = bytes
            try {
                activity.startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = mime
                    putExtra(Intent.EXTRA_TITLE, name)
                }, requestCode)
            } catch (_: Exception) { finishError() }
        }
    }

    fun onActivityResult(code: Int, result: Int, data: Intent?) {
        if (code != requestCode || pending == null) return
        val uri = data?.data
        val bytes = pendingBytes
        pendingBytes = null
        if (result != Activity.RESULT_OK || uri == null || bytes == null) { finish(false); return }
        executor.execute {
            try {
                activity.contentResolver.openOutputStream(uri)?.use { it.write(bytes) } ?: error("Cannot write image")
                finish(true)
            } catch (_: Exception) { finishError() }
        }
    }
    private fun finish(saved: Boolean) = activity.runOnUiThread {
        val result = pending; pending = null; pendingBytes = null
        result?.success(saved)
    }
    private fun finishError() = activity.runOnUiThread {
        val result = pending; pending = null; pendingBytes = null
        result?.error("SAVE_FAILED", "Não foi possível salvar a foto.", null)
    }
    fun close() {
        closed = true
        pending?.error("CLOSED", "Download interrompido.", null)
        pending = null; pendingBytes = null
        executor.shutdown()
    }
}
