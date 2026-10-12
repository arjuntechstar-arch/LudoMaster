package com.ludomaster.app.mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.android.gms.games.PlayGames
import com.google.android.gms.games.PlayGamesSdk

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val configured = getString(R.string.play_games_app_id) != "0"
        if (configured) PlayGamesSdk.initialize(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ludoplay/play_games")
            .setMethodCallHandler { call, result ->
                if (call.method != "signIn") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val clientId = call.argument<String>("serverClientId")
                if (!configured || clientId.isNullOrBlank()) {
                    result.error("UNAVAILABLE", "Play Games is not configured", null)
                    return@setMethodCallHandler
                }
                val client = PlayGames.getGamesSignInClient(this)
                client.signIn().addOnSuccessListener { authentication ->
                    if (!authentication.isAuthenticated) {
                        result.error("CANCELLED", "Play Games sign-in was cancelled", null)
                    } else {
                        client.requestServerSideAccess(clientId, false)
                            .addOnSuccessListener { code -> result.success(code) }
                            .addOnFailureListener { result.error("AUTH_FAILED", "Could not authorize Play Games", null) }
                    }
                }.addOnFailureListener { result.error("SIGN_IN_FAILED", "Could not sign in to Play Games", null) }
            }
    }
}
