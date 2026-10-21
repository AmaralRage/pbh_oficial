package com.amaralstudios.pbh_oficial

import android.app.Activity
import com.spotify.android.appremote.api.ConnectionParams
import com.spotify.android.appremote.api.Connector
import com.spotify.android.appremote.api.SpotifyAppRemote
import com.spotify.protocol.client.CallResult
import com.spotify.protocol.types.PlayerState
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SpotifyRemoteBridge(private val activity: Activity) {
    private var remote: SpotifyAppRemote? = null
    private var generation = 0
    private var connecting = false

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connect" -> connect(call, result)
            "disconnect" -> { close(); result.success(null) }
            else -> {
                val player = remote?.takeIf { it.isConnected }?.playerApi
                if (player == null) {
                    result.error("NOT_CONNECTED", "Conecte o Spotify novamente para ativar o controle em segundo plano.", null)
                    return
                }
                when (call.method) {
                    "play" -> {
                        val uri = call.argument<String>("uri")
                        if (uri == null || !uri.startsWith("spotify:")) {
                            result.error("INVALID_URI", "Selecione uma música ou playlist válida.", null)
                        } else {
                            val index = call.argument<Number>("index")?.toInt()
                            complete(if (index != null) player.skipToIndex(uri, index) else player.play(uri), result)
                        }
                    }
                    "pause" -> complete(player.pause(), result)
                    "resume" -> complete(player.resume(), result)
                    "next" -> complete(player.skipNext(), result)
                    "previous" -> complete(player.skipPrevious(), result)
                    "seek" -> complete(player.seekTo(call.argument<Number>("position")?.toLong() ?: 0L), result)
                    "shuffle" -> complete(player.setShuffle(call.argument<Boolean>("enabled") == true), result)
                    "repeat" -> complete(player.setRepeat(call.argument<Int>("mode") ?: 0), result)
                    "state" -> player.playerState
                        .setResultCallback { state -> result.success(stateMap(state)) }
                        .setErrorCallback { result.error("PLAYBACK_ERROR", "Não foi possível atualizar o player do Spotify.", null) }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun connect(call: MethodCall, result: MethodChannel.Result) {
        if (remote?.isConnected == true) { result.success(null); return }
        if (connecting) { result.error("CONNECTING", "Aguarde a conexão com o Spotify.", null); return }
        if (!SpotifyAppRemote.isSpotifyInstalled(activity)) {
            result.error("NOT_INSTALLED", "Instale e entre no Spotify neste celular para usar o player do PBH.", null)
            return
        }
        val clientId = call.argument<String>("clientId") ?: return result.error("CONFIGURATION", "Client ID ausente.", null)
        val redirect = call.argument<String>("redirectUri") ?: return result.error("CONFIGURATION", "Redirect URI ausente.", null)
        val requestGeneration = generation
        connecting = true
        val params = ConnectionParams.Builder(clientId).setRedirectUri(redirect)
            .showAuthView(call.argument<Boolean>("authorize") == true).build()
        SpotifyAppRemote.connect(activity, params, object : Connector.ConnectionListener {
            override fun onConnected(appRemote: SpotifyAppRemote) {
                if (requestGeneration != generation) {
                    SpotifyAppRemote.disconnect(appRemote)
                    result.error("CANCELED", "Conexão encerrada.", null)
                    return
                }
                connecting = false
                remote = appRemote
                result.success(null)
            }
            override fun onFailure(throwable: Throwable) {
                if (requestGeneration == generation) connecting = false
                result.error("REMOTE_AUTH", "Não foi possível ativar o Spotify em segundo plano. Desconecte e conecte sua conta novamente no PBH para autorizar o controle da reprodução.", null)
            }
        })
    }

    private fun <T> complete(operation: CallResult<T>, result: MethodChannel.Result) {
        operation.setResultCallback { result.success(null) }
            .setErrorCallback { result.error("PLAYBACK_ERROR", "O Spotify recusou o comando. Verifique sua conta e tente novamente.", null) }
    }

    private fun stateMap(state: PlayerState): Map<String, Any?> {
        val track = state.track
        val imageId = track?.imageUri?.raw?.removePrefix("spotify:image:")
        return mapOf(
            "is_playing" to !state.isPaused,
            "progress_ms" to state.playbackPosition,
            "shuffle_state" to state.playbackOptions.isShuffling,
            "repeat_state" to when (state.playbackOptions.repeatMode) { 1 -> "context"; 2 -> "track"; else -> "off" },
            "item" to track?.let {
                mapOf("type" to if (it.isEpisode) "episode" else "track",
                    "uri" to it.uri, "name" to it.name, "duration_ms" to it.duration,
                    "artists" to it.artists.map { artist -> mapOf("name" to artist.name) },
                    "album" to mapOf("name" to it.album.name,
                        "images" to if (imageId != null && imageId.matches(Regex("[a-fA-F0-9]+"))) listOf(mapOf("url" to "https://i.scdn.co/image/$imageId")) else emptyList<Map<String, String>>()),
                    "external_urls" to mapOf("spotify" to "https://open.spotify.com/track/${it.uri.substringAfterLast(':')}"))
            }
        )
    }

    fun close() {
        generation++
        connecting = false
        remote?.let { SpotifyAppRemote.disconnect(it) }
        remote = null
    }
}
