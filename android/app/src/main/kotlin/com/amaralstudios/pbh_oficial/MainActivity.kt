package com.amaralstudios.pbh_oficial

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent

class MainActivity : FlutterActivity() {
    private var spotify: SpotifyRemoteBridge? = null
    private var photos: PhotoDownloadBridge? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        spotify = SpotifyRemoteBridge(this)
        photos = PhotoDownloadBridge(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pbh/photo_download")
            .setMethodCallHandler { call, result -> photos?.handle(call, result) }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pbh/spotify_remote")
            .setMethodCallHandler { call, result -> spotify?.handle(call, result) }
    }
    override fun onDestroy() {
        photos?.close()
        spotify?.close()
        super.onDestroy()
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        photos?.onActivityResult(requestCode, resultCode, data)
    }
}
