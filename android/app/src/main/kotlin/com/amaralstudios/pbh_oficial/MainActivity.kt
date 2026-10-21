package com.amaralstudios.pbh_oficial

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var spotify: SpotifyRemoteBridge? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        spotify = SpotifyRemoteBridge(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pbh/spotify_remote")
            .setMethodCallHandler { call, result -> spotify?.handle(call, result) }
    }
    override fun onDestroy() {
        spotify?.close()
        super.onDestroy()
    }
}
