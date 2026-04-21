package com.edicl.mikan_player

import android.content.Context

object RustlsVerifier {
    init {
        System.loadLibrary("rust")
    }

    external fun init(context: Context): Boolean
}
