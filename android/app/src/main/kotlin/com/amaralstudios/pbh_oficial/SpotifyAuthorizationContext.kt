package com.amaralstudios.pbh_oficial

import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.ServiceConnection
import android.os.Build

/**
 * App Remote 0.8.0 calls getApplicationContext().bindService with flags 65.
 * Android 14+ requires an explicit opt-in for that bound service to display auth.
 * Keep the application context (no Activity leak), and scope the opt-in to the
 * official Spotify protocol service during a user-requested authorization only.
 */
internal class SpotifyAuthorizationContext(
    base: Context,
    private val authorize: Boolean
) : ContextWrapper(base.applicationContext) {
    override fun getApplicationContext(): Context = this

    override fun bindService(service: Intent, connection: ServiceConnection, flags: Int): Boolean {
        val spotifyProtocol = service.`package` == "com.spotify.music" &&
            service.action == "com.spotify.mobile.appprotocol.action.BIND_PROTOCOL_SERVICE"
        val bindingFlags = if (Build.VERSION.SDK_INT >= 34 && authorize && spotifyProtocol) {
            flags or Context.BIND_ALLOW_ACTIVITY_STARTS
        } else flags
        return baseContext.bindService(service, connection, bindingFlags)
    }
}
