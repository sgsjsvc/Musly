import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../models/radio_station.dart';
import 'android_auto_service.dart';
import 'android_system_service.dart';
import 'windows_system_service.dart';
import 'bluetooth_avrcp_service.dart';
import 'samsung_integration_service.dart';
import 'discord_rpc_service.dart';
import 'floating_window_controller.dart';
import 'audio_handler.dart';
import 'storage_service.dart';

/// Immutable snapshot of the current playback state, passed to
/// [ExternalMediaController.updateNowPlaying] so that every external service
/// receives a consistent set of values in a single call.
class PlaybackSnapshot {
  final Song? song;
  final String? artworkUrl;
  final Duration duration;
  final Duration position;
  final bool isPlaying;
  final int currentIndex;
  final int queueLength;
  final bool isRemotePlayback;

  const PlaybackSnapshot({
    this.song,
    this.artworkUrl,
    required this.duration,
    required this.position,
    required this.isPlaying,
    required this.currentIndex,
    required this.queueLength,
    required this.isRemotePlayback,
  });
}

/// Centralises all external media service updates that were previously
/// scattered across [PlayerProvider] (Android Auto, system media controls,
/// Windows SMTC, Bluetooth AVRCP, Samsung, Discord RPC, floating window).
///
/// The owner calls [updateNowPlaying] whenever playback state changes; this
/// class fans the update out to every registered service.
class ExternalMediaController {
  final AndroidAutoService _androidAutoService = AndroidAutoService();
  final AndroidSystemService _androidSystemService = AndroidSystemService();
  final WindowsSystemService _windowsService = WindowsSystemService();
  final BluetoothAvrcpService _bluetoothService = BluetoothAvrcpService();
  final SamsungIntegrationService _samsungService = SamsungIntegrationService();
  late final DiscordRpcService _discordRpcService;
  final MuslyAudioHandler _audioHandler;

  bool _floatingWindowEnabled = false;
  String _discordRpcStateStyle = 'artist';

  // ── Public getters for device info ─────────────────────────────────────
  bool get isSamsungDevice => _samsungService.isSamsungDevice;
  bool get isDexMode => _samsungService.isDexMode;
  bool get hasBluetoothDevice => _bluetoothService.hasConnectedDevices;
  List<BluetoothDeviceInfo> get connectedBluetoothDevices =>
      _bluetoothService.connectedDevices;
  bool get discordRpcEnabled => _discordRpcService.enabled;
  String get discordRpcStateStyle => _discordRpcStateStyle;

  // ── Callbacks from external controls back to the player ────────────────
  VoidCallback? onPlay;
  VoidCallback? onPause;
  VoidCallback? onStop;
  VoidCallback? onSkipNext;
  VoidCallback? onSkipPrevious;
  Function(Duration)? onSeekTo;
  VoidCallback? onTogglePlayPause;
  VoidCallback? onHeadsetHook;
  VoidCallback? onHeadsetDoubleClick;
  Function(String)? onPlayFromMediaId;
  Function(int)? onRemoteVolumeChange;
  // Audio focus callbacks
  VoidCallback? onAudioFocusLoss;
  VoidCallback? onAudioFocusLossTransient;
  VoidCallback? onAudioFocusLossTransientCanDuck;
  VoidCallback? onAudioFocusGain;
  VoidCallback? onBecomingNoisy;
  // Samsung edge panel
  Function(String)? onEdgePanelAction;
  // Samsung DeX mode changes
  VoidCallback? onDexModeEnter;
  VoidCallback? onDexModeExit;

  ExternalMediaController(
    StorageService storageService,
    this._audioHandler,
  ) {
    _discordRpcService = DiscordRpcService(storageService);
  }

  /// Wire the audio handler and platform services so that transport commands
  /// from lock-screen / headset / car head-unit are forwarded to the player.
  Future<void> initialize() async {
    // Audio handler (lock screen / Control Center)
    _audioHandler.onPlay = () {
      onPlay?.call();
      return Future.value();
    };
    _audioHandler.onPause = () {
      onPause?.call();
      return Future.value();
    };
    _audioHandler.onStop = () {
      onStop?.call();
      return Future.value();
    };
    _audioHandler.onSkipNext = () {
      onSkipNext?.call();
      return Future.value();
    };
    _audioHandler.onSkipPrevious = () {
      onSkipPrevious?.call();
      return Future.value();
    };
    _audioHandler.onSeekTo = (pos) {
      onSeekTo?.call(pos);
      return Future.value();
    };
    _audioHandler.onTogglePlayPause = () {
      onTogglePlayPause?.call();
      return Future.value();
    };

    // Android Auto
    try {
      _androidAutoService.initialize();
      _androidAutoService.onPlay = () => onPlay?.call();
      _androidAutoService.onPause = () => onPause?.call();
      _androidAutoService.onStop = () => onStop?.call();
      _androidAutoService.onSkipNext = () => onSkipNext?.call();
      _androidAutoService.onSkipPrevious = () => onSkipPrevious?.call();
      _androidAutoService.onSeekTo = (pos) => onSeekTo?.call(pos);
      _androidAutoService.onPlayFromMediaId =
          (id) => onPlayFromMediaId?.call(id);
      _androidAutoService.onSetVolume =
          (vol) => onRemoteVolumeChange?.call(vol);
    } catch (_) {}

    // Android system media controls
    try {
      await _androidSystemService.initialize();
      _androidSystemService.onPlay = () => onPlay?.call();
      _androidSystemService.onPause = () => onPause?.call();
      _androidSystemService.onStop = () => onStop?.call();
      _androidSystemService.onSkipNext = () => onSkipNext?.call();
      _androidSystemService.onSkipPrevious = () => onSkipPrevious?.call();
      _androidSystemService.onSeekTo = (pos) => onSeekTo?.call(pos);
      _androidSystemService.onSeekForward = (interval) {
        // PlayerProvider resolves _position + interval
        onSeekTo?.call(interval);
      };
      _androidSystemService.onSeekBackward = (interval) {
        onSeekTo?.call(interval);
      };
      _androidSystemService.onHeadsetHook = () => onHeadsetHook?.call();
      _androidSystemService.onHeadsetDoubleClick =
          () => onHeadsetDoubleClick?.call();
      _androidSystemService.onAudioFocusLoss =
          () => onAudioFocusLoss?.call();
      _androidSystemService.onAudioFocusLossTransient =
          () => onAudioFocusLossTransient?.call();
      _androidSystemService.onAudioFocusLossTransientCanDuck =
          () => onAudioFocusLossTransientCanDuck?.call();
      _androidSystemService.onAudioFocusGain =
          () => onAudioFocusGain?.call();
      _androidSystemService.onBecomingNoisy =
          () => onBecomingNoisy?.call();
    } catch (_) {}

    // Windows SMTC
    try {
      await _windowsService.initialize();
      _windowsService.onPlay = () => onPlay?.call();
      _windowsService.onPause = () => onPause?.call();
      _windowsService.onStop = () => onStop?.call();
      _windowsService.onSkipNext = () => onSkipNext?.call();
      _windowsService.onSkipPrevious = () => onSkipPrevious?.call();
      _windowsService.onSeekTo = (pos) => onSeekTo?.call(pos);
    } catch (_) {}

    // Bluetooth AVRCP
    try {
      await _bluetoothService.initialize();
      _bluetoothService.onPlay = () => onPlay?.call();
      _bluetoothService.onPause = () => onPause?.call();
      _bluetoothService.onStop = () => onStop?.call();
      _bluetoothService.onSkipNext = () => onSkipNext?.call();
      _bluetoothService.onSkipPrevious = () => onSkipPrevious?.call();
      _bluetoothService.onSeekTo = (pos) => onSeekTo?.call(pos);
      _bluetoothService.registerAbsoluteVolumeControl();
    } catch (_) {}

    // Samsung
    try {
      _samsungService.initialize();
      _samsungService.onDexModeEnter = () => onDexModeEnter?.call();
      _samsungService.onDexModeExit = () => onDexModeExit?.call();
      _samsungService.onEdgePanelAction =
          (action) => onEdgePanelAction?.call(action);
    } catch (_) {}

    // Discord RPC (desktop only)
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      try {
        _discordRpcService.initialize();
      } catch (_) {}
    }

    // Floating Window (Android only)
    if (!kIsWeb && Platform.isAndroid) {
      try {
        FloatingWindowController.init((action) {
          debugPrint('[ExternalMedia] Floating window action received: $action');
          switch (action) {
            case 'play_pause':
              onTogglePlayPause?.call();
              break;
            case 'next':
              onSkipNext?.call();
              break;
            case 'previous':
            case 'prev':
              onSkipPrevious?.call();
              break;
          }
        });
      } catch (e) {
        debugPrint('[ExternalMedia] FloatingWindowController.init failed: $e');
      }
    }
  }

  /// Fan out the current playback state to all external services.
  void updateNowPlaying(PlaybackSnapshot snapshot) {
    final song = snapshot.song;
    if (song == null) return;

    final effectiveDuration = snapshot.duration.inMilliseconds > 0
        ? snapshot.duration
        : Duration(seconds: song.duration ?? 0);

    // Android system service
    _androidSystemService.updateFromSong(
      song: song,
      artworkUrl: snapshot.artworkUrl,
      duration: effectiveDuration,
      position: snapshot.position,
      isPlaying: snapshot.isPlaying,
      currentIndex: snapshot.currentIndex,
      queueLength: snapshot.queueLength,
    );

    // Windows SMTC
    _windowsService.updatePlaybackState(
      song: song,
      artworkUrl: snapshot.artworkUrl,
      duration: effectiveDuration,
      position: snapshot.position,
      isPlaying: snapshot.isPlaying,
    );

    // Bluetooth AVRCP
    _bluetoothService.updateFromSong(
      song: song,
      artworkUrl: snapshot.artworkUrl,
      duration: effectiveDuration,
      position: snapshot.position,
      isPlaying: snapshot.isPlaying,
      currentIndex: snapshot.currentIndex,
      queueLength: snapshot.queueLength,
    );

    // Samsung
    if (_samsungService.isSamsungDevice) {
      _samsungService.updateFromSong(
        song: song,
        artworkUrl: snapshot.artworkUrl,
        duration: effectiveDuration,
        position: snapshot.position,
        isPlaying: snapshot.isPlaying,
      );
    }

    // Floating window
    if (_floatingWindowEnabled && Platform.isAndroid) {
      FloatingWindowController.update(
        title: song.title,
        artist: song.artist ?? 'Unknown Artist',
        isPlaying: snapshot.isPlaying,
      );
    }
  }

  /// Update Android Auto playback state and audio_service handler.
  void updateAndroidAuto(PlaybackSnapshot snapshot) {
    final song = snapshot.song;
    if (song == null) return;

    final effectiveDuration = snapshot.duration.inMilliseconds > 0
        ? snapshot.duration
        : Duration(seconds: song.duration ?? 0);

    _androidAutoService.updatePlaybackState(
      songId: song.id,
      title: song.title,
      artist: song.artist ?? '',
      album: song.album ?? '',
      artworkUrl: snapshot.artworkUrl,
      duration: effectiveDuration,
      position: snapshot.position,
      isPlaying: snapshot.isPlaying,
    );

    _audioHandler.updateNowPlaying(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      artworkUrl: snapshot.artworkUrl,
      duration: effectiveDuration,
    );

    _updateDiscordRpc(snapshot);
    updateNowPlaying(snapshot);
  }

  /// Update services for radio station playback.
  void updateForRadio(RadioStation station) {
    _windowsService.updatePlaybackState(
      song: null,
      isPlaying: true,
      position: Duration.zero,
      duration: Duration.zero,
      artworkUrl: null,
    );

    _androidSystemService.updatePlaybackState(
      songId: station.id,
      title: station.name,
      artist: 'Internet Radio',
      album: station.homePageUrl ?? '',
      artworkUrl: null,
      duration: Duration.zero,
      position: Duration.zero,
      isPlaying: true,
    );
  }

  /// Show the floating window (Android only).
  void showFloatingWindow({
    required String title,
    required String artist,
    required bool isPlaying,
  }) {
    if (!Platform.isAndroid) return;
    FloatingWindowController.show(
      title: title,
      artist: artist,
      isPlaying: isPlaying,
    );
    FloatingWindowController.updateSongTitle(title);
  }

  /// Update floating window state.
  void updateFloatingWindow({
    required String title,
    required String artist,
    required bool isPlaying,
  }) {
    if (!Platform.isAndroid) return;
    FloatingWindowController.update(
      title: title,
      artist: artist,
      isPlaying: isPlaying,
    );
    FloatingWindowController.updateSongTitle(title);
  }

  void hideFloatingWindow() => FloatingWindowController.hide();

  bool get floatingWindowEnabled => _floatingWindowEnabled;

  void setFloatingWindowEnabled(bool enabled) {
    _floatingWindowEnabled = enabled;
    if (!enabled) FloatingWindowController.hide();
  }

  Future<void> requestFloatingWindowPermission() =>
      FloatingWindowController.requestPermission();

  // ── Android system service proxies ─────────────────────────────────────

  AndroidAutoService get androidAutoService => _androidAutoService;
  AndroidSystemService get androidSystemService => _androidSystemService;

  Future<bool> requestAudioFocus() =>
      _androidSystemService.requestAudioFocus();

  void setRemotePlayback({required bool isRemote, int volume = 50}) {
    _androidSystemService.setRemotePlayback(isRemote: isRemote, volume: volume);
  }

  void updateRemoteVolume(int volume) {
    _androidSystemService.updateRemoteVolume(volume);
  }

  // ── Bluetooth proxies ──────────────────────────────────────────────────

  Future<bool> isA2dpConnected() => _bluetoothService.isA2dpConnected();

  void onBluetoothDeviceConnected(Function(dynamic) callback) {
    _bluetoothService.onDeviceConnected = callback;
  }

  void onBluetoothDeviceDisconnected(Function(dynamic) callback) {
    _bluetoothService.onDeviceDisconnected = callback;
  }

  // ── Discord RPC ────────────────────────────────────────────────────────

  void _updateDiscordRpc(PlaybackSnapshot snapshot) {
    try {
      final song = snapshot.song;
      if (song == null) {
        _discordRpcService.clearPresence();
        return;
      }

      final int now = DateTime.now().millisecondsSinceEpoch;
      final int startTimestamp = now - snapshot.position.inMilliseconds;
      final int? endTimestamp =
          snapshot.isPlaying && snapshot.duration.inMilliseconds > 0
              ? startTimestamp + snapshot.duration.inMilliseconds
              : null;

      String stateText;
      switch (_discordRpcStateStyle) {
        case 'song_title':
          stateText = song.title;
          break;
        case 'app_name':
          stateText = 'Musly';
          break;
        case 'artist':
        default:
          stateText = song.artist ?? 'Unknown Artist';
      }

      _discordRpcService.updatePresence(
        state: stateText,
        details: song.title,
        largeImageKey: 'musly_logo',
        largeImageText: song.album,
        smallImageKey: 'musly_logo',
        smallImageText: snapshot.isPlaying ? 'Playing' : 'Paused',
        startTime: startTimestamp,
        endTime: endTimestamp,
      );
    } catch (_) {}
  }

  Future<void> setDiscordRpcEnabled(bool enabled) async {
    try {
      await _discordRpcService.setEnabled(enabled);
    } catch (_) {}
  }

  Future<void> loadDiscordRpcStateStyle(StorageService storageService) async {
    _discordRpcStateStyle = await storageService.getDiscordRpcStateStyle();
  }

  Future<void> setDiscordRpcStateStyle(
      String style, StorageService storageService) async {
    _discordRpcStateStyle = style;
    await storageService.saveDiscordRpcStateStyle(style);
  }

  void clearDiscordPresence() {
    try {
      _discordRpcService.clearPresence();
    } catch (_) {}
  }

  // ── Dispose ────────────────────────────────────────────────────────────

  void dispose() {
    try { _androidAutoService.dispose(); } catch (_) {}
    try { _androidSystemService.dispose(); } catch (_) {}
    try { _windowsService.dispose(); } catch (_) {}
    try { _bluetoothService.dispose(); } catch (_) {}
    try { _samsungService.dispose(); } catch (_) {}
    try { _discordRpcService.shutdown(); } catch (_) {}
  }
}
