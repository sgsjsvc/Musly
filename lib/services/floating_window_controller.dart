import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Controls the Android floating window overlay.
/// Sends show/hide/update commands to the native service and receives
/// button click callbacks (play_pause, next) from the overlay.
class FloatingWindowController {
  static const MethodChannel _channel =
      MethodChannel('com.musly/floating_window');

  static Function(String)? _onControlCallback;

  /// Initialize the controller with a callback for overlay button actions.
  static void init(Function(String) onAction) {
    _onControlCallback = onAction;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onControlAction') {
        final action = call.arguments as String;
        _onControlCallback?.call(action);
      }
    });
  }

  /// 安全调用原生方法，捕获所有异常防止 UI 卡死
  static Future<T?> _safeInvoke<T>(String method,
      [Map<String, dynamic>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } catch (e) {
      debugPrint('[FloatingWindow] $method failed: $e');
      return null;
    }
  }

  static Future<bool> checkPermission() async {
    return await _safeInvoke<bool>('checkPermission') ?? false;
  }

  static Future<void> requestPermission() async {
    await _safeInvoke('requestPermission');
  }

  static Future<void> show({
    required String title,
    required String artist,
    required bool isPlaying,
  }) async {
    await _safeInvoke('show', {
      'title': title,
      'artist': artist,
      'isPlaying': isPlaying,
    });
  }

  static Future<void> hide() async {
    await _safeInvoke('hide');
  }

  static Future<void> update({
    required String title,
    required String artist,
    required bool isPlaying,
  }) async {
    await _safeInvoke('update', {
      'title': title,
      'artist': artist,
      'isPlaying': isPlaying,
    });
  }

  /// 向原生端发送当前歌名（用于跑马灯滚动）
  static Future<void> updateSongTitle(String title) async {
    await _safeInvoke('updateSongTitle', {'title': title});
  }

  /// 向原生端发送当前句歌词进行滚动显示
  static Future<void> updateLyrics(String lyrics) async {
    await _safeInvoke('updateLyrics', {'lyrics': lyrics});
  }

  static void dispose() {
    _onControlCallback = null;
    _channel.setMethodCallHandler(null);
  }
}
