package com.edicl.mikan_player

import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Initialize the Android certificate verifier before any Rust networking starts.
        if (!RustlsVerifier.init(applicationContext)) {
            Log.e("MikanPlayer", "Failed to initialize rustls-platform-verifier")
        }

        super.onCreate(savedInstanceState)
    }
}
