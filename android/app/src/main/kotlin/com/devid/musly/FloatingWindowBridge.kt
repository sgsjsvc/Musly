package com.devid.musly

object FloatingWindowBridge {
    var onControlAction: ((String) -> Unit)? = null

    var currentSongTitle: String = "未在播放"
        set(value) {
            field = value
            onSongTitleChanged?.invoke(value)
        }
    var onSongTitleChanged: ((String) -> Unit)? = null

    var currentLyrics: String = ""
        set(value) {
            field = value
            onLyricsChanged?.invoke(value)
        }
    var onLyricsChanged: ((String) -> Unit)? = null

    var currentArtworkUrl: String = ""
    var currentDuration: Long = 0
    var currentPosition: Long = 0
    
    var onProgressChanged: ((Long, Long) -> Unit)? = null
    var onArtworkChanged: ((String) -> Unit)? = null
}
