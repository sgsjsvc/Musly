package com.devid.musly

/**
 * Bridge between FloatingWindowService and FloatingWindowPlugin.
 * Receives button click events from the floating window and forwards
 * them to the Plugin, which then notifies Flutter via MethodChannel.
 */
object FloatingWindowBridge {
    // 播放控制事件回调
    var onControlAction: ((String) -> Unit)? = null

    // 歌名更新监听
    var currentSongTitle: String = "暂无播放"
        set(value) {
            field = value
            onSongTitleChanged?.invoke(value)
        }

    var onSongTitleChanged: ((String) -> Unit)? = null
}
