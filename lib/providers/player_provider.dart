import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;

import 'package:audio_session/audio_session.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/subsonic_service.dart';
import '../services/offline_service.dart';
import '../services/recommendation_service.dart';
import '../services/replay_gain_service.dart';
import '../services/auto_dj_service.dart';
import '../services/storage_service.dart';
import '../services/cast_service.dart';
import '../services/upnp_service.dart';
import '../services/jukebox_service.dart';
import '../services/audio_handler.dart';
import '../services/fade_settings_service.dart';
import '../services/lock_screen_lyrics_service.dart';
import '../services/transcoding_service.dart';
import '../services/queue_persistence_manager.dart';
import '../services/sleep_timer_controller.dart';
import '../services/external_media_controller.dart';
import '../services/bluetooth_avrcp_service.dart';
import '../providers/library_provider.dart';

enum RepeatMode { off, all, one }

class PlayerProvider extends ChangeNotifier with WidgetsBindingObserver {
  final SubsonicService _subsonicService;
  late final StorageService _storageService;
  final MuslyAudioHandler _audioHandler;

  // Convenience getter — use this everywhere just_audio is accessed directly.
  AudioPlayer get _audioPlayer => _audioHandler.player;
  final OfflineService _offlineService = OfflineService();
  final ReplayGainService _replayGainService = ReplayGainService();
  final AutoDjService _autoDjService = AutoDjService();
  final CastService _castService;
  late final UpnpService _upnpService;
  final LockScreenLyricsService _lyricsService = LockScreenLyricsService();

  // Controllers/Managers split from the provider
  final QueuePersistenceManager _queuePersistence = QueuePersistenceManager();
  final SleepTimerController _sleepTimerController = SleepTimerController();
  late final ExternalMediaController _externalMediaController;

  // Locally managed settings cache
  bool _floatingWindowEnabled = false;
  bool _floatingWindowCacheLoaded = false;
  bool _bootAutoStart = false;
  bool _bootAutoStartLoaded = false;

  LibraryProvider? _libraryProvider;
  RecommendationService? _recommendationService;

  List<Song> _queue = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _shuffleEnabled = false;
  bool _gaplessEnabled = true;
  final List<String> _shuffleHistory = [];
  RepeatMode _repeatMode = RepeatMode.off;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Song? _currentSong;
  double _volume = 1.0;

  /// True only while audio is actually being rendered on a remote device.
  /// Distinct from isConnected: if the user plays a radio station while a
  /// UPnP renderer is connected, the audio is still local, so this stays false.
  bool _isRenderingRemotely = false;

  String? _resolvedArtworkUrl;

  RadioStation? _currentRadioStation;
  bool _isPlayingRadio = false;

  bool _hasPlayedOnce = false;
  final bool _reactivatingSession = false;

  Timer? _jukeboxPollTimer;

  // Fade in/out
  final FadeSettingsService _fadeSettingsService = FadeSettingsService();
  Timer? _fadeTimer;
  bool _isFading = false;

  final JukeboxService _jukeboxService;
  final TranscodingService _transcodingService;

  double _playbackSpeed = 1.0;
  double _pitch = 1.0;
  bool _pitchCorrection = true;

  // Track if absolute volume control or general A2DP connection active
  bool _isA2dpAudioActive = false;

  PlayerProvider(
    this._subsonicService,
    StorageService storageService,
    this._castService,
    this._upnpService,
    this._audioHandler,
    this._jukeboxService,
    this._transcodingService,
  ) {
    _storageService = storageService;
    _externalMediaController = ExternalMediaController(storageService, _audioHandler);

    _castService.addListener(_onCastStateChanged);
    _upnpService.addListener(_onUpnpStateChanged);
    _upnpService.onRendererLost = _onUpnpRendererLost;
    _jukeboxService.addListener(_onJukeboxEnabledChanged);

    // Initialize sleep timer callbacks
    _sleepTimerController.onTimerExpired = () => pause();
    _sleepTimerController.onSetVolume = (v) => _audioPlayer.setVolume(v);
    _sleepTimerController.addListener(notifyListeners);

    _initializePlayer();
    _onJukeboxEnabledChanged();
    _initializeAutoDj();
    _initializeLyricsService();

    // Wire up external controls
    _wireExternalMediaCallbacks();

    _restoreQueueState();

    // Initialize floating window controller with playback control callbacks
    if (!kIsWeb && Platform.isAndroid) {
      _externalMediaController.initialize().then((_) {
        _externalMediaController.androidAutoService.onGetAlbumSongs = _getAlbumSongsForAndroidAuto;
        _externalMediaController.androidAutoService.onGetArtistAlbums = _getArtistAlbumsForAndroidAuto;
        _externalMediaController.androidAutoService.onGetPlaylistSongs = _getPlaylistSongsForAndroidAuto;
        _externalMediaController.androidAutoService.onSearch = _searchForAndroidAuto;
        _externalMediaController.androidAutoService.onPlayFromSearch = _playFromSearchForAndroidAuto;
        _externalMediaController.androidAutoService.onRequestLibraryData = _onRequestLibraryData;
      });
    } else {
      _externalMediaController.initialize();
    }

    // Register app lifecycle observer to save state on iOS when app goes to background
    WidgetsBinding.instance.addObserver(this);
  }

  /// Handle app lifecycle changes - save queue state when going to background (important for iOS)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      debugPrint(
          '[Player] App lifecycle state: $state - saving queue state immediately');
      _saveQueueStateImmediate();
      // Show floating window when going to background (if enabled)
      _showFloatingWindowIfNeededAsync().catchError((e) {
        debugPrint('[Player] Floating window show error: $e');
      });
    } else if (state == AppLifecycleState.detached) {
      // App being destroyed — ensure floating window is closed
      if (Platform.isAndroid) {
        _externalMediaController.hideFloatingWindow();
      }
    }
  }

  /// 异步显示悬浮窗
  Future<void> _showFloatingWindowIfNeededAsync() async {
    if (!Platform.isAndroid) return;

    final enabled = _externalMediaController.floatingWindowEnabled;
    debugPrint('[Player] 悬浮窗设置状态: $enabled, 播放状态: $_isPlaying, 当前歌曲: ${_currentSong?.title}');

    if (_isPlaying && _currentSong != null && enabled) {
      debugPrint('[Player] 显示悬浮窗...');
      _showFloatingWindowIfNeeded();
    }
  }

  void _wireExternalMediaCallbacks() {
    _externalMediaController.onPlay = play;
    _externalMediaController.onPause = pause;
    _externalMediaController.onStop = stop;
    _externalMediaController.onSkipNext = skipNext;
    _externalMediaController.onSkipPrevious = skipPrevious;
    _externalMediaController.onSeekTo = seek;
    _externalMediaController.onTogglePlayPause = togglePlayPause;
    _externalMediaController.onHeadsetHook = togglePlayPause;
    _externalMediaController.onHeadsetDoubleClick = skipNext;
    _externalMediaController.onPlayFromMediaId = _playFromMediaId;
    _externalMediaController.onRemoteVolumeChange = _onRemoteVolumeChange;

    _externalMediaController.onAudioFocusLoss = () {
      if (isRemotePlayback) return;
      pause();
    };
    _externalMediaController.onAudioFocusLossTransient = () {
      if (isRemotePlayback) return;
      pause();
    };
    _externalMediaController.onAudioFocusLossTransientCanDuck = () {
      if (isRemotePlayback) return;
      _smoothVolumeChange(0.3);
    };
    _externalMediaController.onAudioFocusGain = () {
      if (isRemotePlayback) return;
      _smoothVolumeChange(_volume);
    };
    _externalMediaController.onBecomingNoisy = () {
      if (isRemotePlayback) return;
      pause();
    };

    _externalMediaController.onBluetoothDeviceConnected((device) {
      debugPrint('Bluetooth device connected: ${device.name}');
      _externalMediaController.isA2dpConnected().then((active) {
        _isA2dpAudioActive = active;
        debugPrint('Bluetooth A2DP active: $_isA2dpAudioActive');
      });
      _updateAllServices();
    });

    _externalMediaController.onBluetoothDeviceDisconnected((device) {
      debugPrint('Bluetooth device disconnected: ${device.name}');
      _externalMediaController.isA2dpConnected().then((active) {
        _isA2dpAudioActive = active;
        debugPrint('Bluetooth A2DP active: $_isA2dpAudioActive');
      });
    });

    _externalMediaController.onEdgePanelAction = (action) {
      switch (action) {
        case 'play':
          play();
          break;
        case 'pause':
          pause();
          break;
        case 'next':
          skipNext();
          break;
        case 'previous':
          skipPrevious();
          break;
      }
    };

    _externalMediaController.onDexModeEnter = () => notifyListeners();
    _externalMediaController.onDexModeExit = () => notifyListeners();
  }

  // ── Persistent Queue ───────────────────────────────────────────────────────

  void _saveQueueState() {
    _queuePersistence.save(
      queue: _queue,
      currentIndex: _currentIndex,
      currentSongId: _currentSong?.id,
      position: _position,
    );
  }

  void _saveQueueStateImmediate() {
    _queuePersistence.saveImmediate(
      queue: _queue,
      currentIndex: _currentIndex,
      currentSongId: _currentSong?.id,
      position: _position,
    );
  }

  Future<void> _restoreQueueState() async {
    final restored = await _queuePersistence.restore();
    if (restored != null) {
      _queue = restored.songs;
      _currentIndex = restored.currentIndex;
      _currentSong = restored.songs[restored.currentIndex];
      _position = restored.position;
      final songDurationSecs = restored.songs[restored.currentIndex].duration;
      if (songDurationSecs != null && songDurationSecs > 0) {
        _duration = Duration(seconds: songDurationSecs);
      }
      notifyListeners();
    }
  }

  void _clearPersistedQueue() {
    _queuePersistence.clear();
  }

  // ── Jukebox mode ─────────────────────────────────────────────────────────

  void _onJukeboxEnabledChanged() {
    if (_jukeboxService.enabled) {
      _startJukeboxPolling();
    } else {
      _stopJukeboxPolling();
    }
  }

  void _startJukeboxPolling() {
    _stopJukeboxPolling();
    _jukeboxPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _pollJukebox();
    });
    _pollJukebox();
  }

  void _stopJukeboxPolling() {
    _jukeboxPollTimer?.cancel();
    _jukeboxPollTimer = null;
  }

  Future<void> _pollJukebox() async {
    if (!_jukeboxService.enabled) return;
    try {
      await _jukeboxService.refresh(_subsonicService);
      _syncFromJukeboxStatus();
    } catch (e) {
      debugPrint('Jukebox poll error: $e');
    }
  }

  void _syncFromJukeboxStatus() {
    if (!_jukeboxService.enabled) return;
    final status = _jukeboxService.status;
    final song = status.currentSong;

    bool changed = false;
    if (song != null && song.id != _currentSong?.id) {
      _currentSong = song;
      _resolvedArtworkUrl = null;
      changed = true;
    }
    if (_isPlaying != status.playing) {
      _isPlaying = status.playing;
      changed = true;
    }
    if (_position != status.position) {
      _position = status.position;
      changed = true;
    }
    if (status.playlist.isNotEmpty && !identical(_queue, status.playlist)) {
      _queue = List.from(status.playlist);
      changed = true;
    }
    final clampedIndex = status.currentIndex.clamp(
      0,
      (_queue.length - 1).clamp(0, double.maxFinite.toInt()),
    );
    if (_currentIndex != clampedIndex) {
      _currentIndex = clampedIndex;
      changed = true;
    }
    if (changed) {
      notifyListeners();
      _updateAllServices();
      _updateAndroidAuto();
    }
  }

  void setLibraryProvider(LibraryProvider libraryProvider) {
    _libraryProvider = libraryProvider;
  }

  void setRecommendationService(RecommendationService recommendationService) {
    _recommendationService = recommendationService;
    _autoDjService.setServices(_subsonicService, recommendationService);
  }

  AutoDjService get autoDjService => _autoDjService;
  LockScreenLyricsService get lyricsService => _lyricsService;

  Future<void> _initializeAutoDj() async {
    await _autoDjService.initialize();
    _autoDjService.setServices(_subsonicService, _recommendationService);
  }

  Future<void> _initializeLyricsService() async {
    await _lyricsService.initialize();
  }

  void _onRequestLibraryData() {
    debugPrint(
        'PlayerProvider: Android Auto requested library data');
  }

  Future<List<Map<String, String>>> _getAlbumSongsForAndroidAuto(
    String albumId,
  ) async {
    if (_offlineService.isOfflineMode && _libraryProvider != null) {
      await _offlineService.initialize();
      final downloadedIds = _offlineService.getDownloadedSongIds().toSet();
      final offlineSongs = _libraryProvider!.cachedAllSongs
          .where((s) => s.albumId == albumId && downloadedIds.contains(s.id))
          .toList();
      if (offlineSongs.isNotEmpty) {
        return offlineSongs
            .map(
              (song) => {
                'id': song.id,
                'title': song.title,
                'artist': song.artist ?? '',
                'album': song.album ?? '',
                'artworkUrl': _offlineService.getLocalCoverArtPath(song.id) !=
                        null
                    ? Uri.file(_offlineService.getLocalCoverArtPath(song.id)!)
                        .toString()
                    : _subsonicService.getCoverArtUrl(song.coverArt, size: 300),
                'duration': (song.duration ?? 0).toString(),
              },
            )
            .toList();
      }
    }
    try {
      final songs = await _subsonicService.getAlbumSongs(albumId);
      return songs
          .map(
            (song) => {
              'id': song.id,
              'title': song.title,
              'artist': song.artist ?? '',
              'album': song.album ?? '',
              'artworkUrl': _subsonicService.getCoverArtUrl(
                song.coverArt,
                size: 300,
              ),
              'duration': (song.duration ?? 0).toString(),
            },
          )
          .toList();
    } catch (e) {
      debugPrint('Error getting album songs for Android Auto: $e');
      return [];
    }
  }

  Future<List<Map<String, String>>> _getArtistAlbumsForAndroidAuto(
    String artistId,
  ) async {
    if (_offlineService.isOfflineMode && _libraryProvider != null) {
      await _offlineService.initialize();
      final downloadedIds = _offlineService.getDownloadedSongIds().toSet();
      final albumIdsWithDownloads = _libraryProvider!.cachedAllSongs
          .where((s) => s.artistId == artistId && downloadedIds.contains(s.id))
          .map((s) => s.albumId)
          .whereType<String>()
          .toSet();
      final offlineAlbums = _libraryProvider!.cachedAllAlbums
          .where((a) => albumIdsWithDownloads.contains(a.id))
          .toList();
      if (offlineAlbums.isNotEmpty) {
        return offlineAlbums
            .map(
              (album) => {
                'id': album.id,
                'name': album.name,
                'artist': album.artist ?? '',
                'artworkUrl': _subsonicService.getCoverArtUrl(
                  album.coverArt,
                  size: 300,
                ),
              },
            )
            .toList();
      }
    }
    try {
      final albums = await _subsonicService.getArtistAlbums(artistId);
      return albums
          .map(
            (album) => {
              'id': album.id,
              'name': album.name,
              'artist': album.artist ?? '',
              'artworkUrl': _subsonicService.getCoverArtUrl(
                album.coverArt,
                size: 300,
              ),
            },
          )
          .toList();
    } catch (e) {
      debugPrint('Error getting artist albums for Android Auto: $e');
      return [];
    }
  }

  Future<List<Map<String, String>>> _getPlaylistSongsForAndroidAuto(
    String playlistId,
  ) async {
    if (_offlineService.isOfflineMode && _libraryProvider != null) {
      await _offlineService.initialize();
      final downloadedIds = _offlineService.getDownloadedSongIds().toSet();
      final cachedPlaylist = _libraryProvider!.playlists
          .where((p) => p.id == playlistId)
          .firstOrNull;
      if (cachedPlaylist?.songs != null && cachedPlaylist!.songs!.isNotEmpty) {
        final offlineSongs = cachedPlaylist.songs!
            .where((s) => downloadedIds.contains(s.id))
            .toList();
        if (offlineSongs.isNotEmpty) {
          return offlineSongs
              .map(
                (song) => {
                  'id': song.id,
                  'title': song.title,
                  'artist': song.artist ?? '',
                  'album': song.album ?? '',
                  'artworkUrl': _offlineService.getLocalCoverArtPath(song.id) !=
                          null
                      ? Uri.file(_offlineService.getLocalCoverArtPath(song.id)!)
                          .toString()
                      : _subsonicService.getCoverArtUrl(song.coverArt,
                          size: 300),
                  'duration': (song.duration ?? 0).toString(),
                },
              )
              .toList();
        }
      }
    }
    try {
      final playlist = await _subsonicService.getPlaylist(playlistId);
      final songs = playlist.songs ?? [];
      return songs
          .map(
            (song) => {
              'id': song.id,
              'title': song.title,
              'artist': song.artist ?? '',
              'album': song.album ?? '',
              'artworkUrl': _subsonicService.getCoverArtUrl(
                song.coverArt,
                size: 300,
              ),
              'duration': (song.duration ?? 0).toString(),
            },
          )
          .toList();
    } catch (e) {
      debugPrint('Error getting playlist songs for Android Auto: $e');
      return [];
    }
  }

  Future<List<Map<String, String>>> _searchForAndroidAuto(
    String query,
  ) async {
    if (_offlineService.isOfflineMode && _libraryProvider != null) {
      await _offlineService.initialize();
      final downloadedIds = _offlineService.getDownloadedSongIds().toSet();
      final lowerQuery = query.toLowerCase();
      final offlineResults = _libraryProvider!.cachedAllSongs
          .where(
            (s) =>
                downloadedIds.contains(s.id) &&
                (s.title.toLowerCase().contains(lowerQuery) ||
                    (s.artist?.toLowerCase().contains(lowerQuery) ?? false) ||
                    (s.album?.toLowerCase().contains(lowerQuery) ?? false)),
          )
          .take(20)
          .toList();
      return offlineResults
          .map(
            (song) => {
              'id': song.id,
              'title': song.title,
              'artist': song.artist ?? '',
              'album': song.album ?? '',
              'artworkUrl': _offlineService.getLocalCoverArtPath(song.id) !=
                      null
                  ? Uri.file(_offlineService.getLocalCoverArtPath(song.id)!)
                      .toString()
                  : _subsonicService.getCoverArtUrl(song.coverArt, size: 300),
              'duration': (song.duration ?? 0).toString(),
            },
          )
          .toList();
    }
    try {
      final results = await _subsonicService.search(
        query,
        songCount: 20,
        albumCount: 0,
        artistCount: 0,
      );
      return results.songs
          .map(
            (song) => {
              'id': song.id,
              'title': song.title,
              'artist': song.artist ?? '',
              'album': song.album ?? '',
              'artworkUrl': _subsonicService.getCoverArtUrl(
                song.coverArt,
                size: 300,
              ),
              'duration': (song.duration ?? 0).toString(),
            },
          )
          .toList();
    } catch (e) {
      debugPrint('Android Auto search error: $e');
      return [];
    }
  }

  Future<void> _playFromSearchForAndroidAuto(String query) async {
    try {
      if (query.trim().isEmpty) {
        if (_currentSong != null) {
          await play();
        } else if (_libraryProvider != null &&
            _libraryProvider!.randomSongs.isNotEmpty) {
          final songs = _libraryProvider!.randomSongs;
          await playSong(songs.first, playlist: songs, startIndex: 0);
        }
        return;
      }

      final results = await _subsonicService.search(
        query,
        songCount: 20,
        albumCount: 0,
        artistCount: 0,
      );
      if (results.songs.isNotEmpty) {
        await playSong(
          results.songs.first,
          playlist: results.songs,
          startIndex: 0,
        );
      }
    } catch (e) {
      debugPrint('Android Auto playFromSearch error: $e');
    }
  }

  Future<void> _playFromMediaId(String mediaId) async {
    final queueIndex = _queue.indexWhere((song) => song.id == mediaId);
    if (queueIndex != -1) {
      await skipToIndex(queueIndex);
      return;
    }

    if (_libraryProvider != null) {
      final randomSongs = _libraryProvider!.randomSongs;
      final songIndex = randomSongs.indexWhere((song) => song.id == mediaId);
      if (songIndex != -1) {
        await playSong(
          randomSongs[songIndex],
          playlist: randomSongs,
          startIndex: songIndex,
        );
        return;
      }
    }

    try {
      final searchResults = await _subsonicService.search(
        mediaId,
        songCount: 5,
      );
      if (searchResults.songs.isNotEmpty) {
        final song = searchResults.songs.firstWhere(
          (s) => s.id == mediaId,
          orElse: () => searchResults.songs.first,
        );
        await playSong(song);
        return;
      }
    } catch (e) {
      debugPrint('Android Auto playFromMediaId error: $e');
    }
  }

  String? _resolveArtworkUrl() {
    if (_currentSong == null) return null;
    if (_currentSong!.coverArt == null) return null;
    if (_currentSong!.isLocal) {
      return Uri.file(_currentSong!.coverArt!).toString();
    }

    return _resolvedArtworkUrl;
  }

  Future<void> _refreshArtworkUrl() async {
    final song = _currentSong;
    if (song == null || song.coverArt == null) {
      _resolvedArtworkUrl = null;
      return;
    }
    if (song.isLocal) {
      _resolvedArtworkUrl = Uri.file(song.coverArt!).toString();
      return;
    }

    await _offlineService.initialize();

    final localPath = _offlineService.getLocalCoverArtPath(song.id);
    if (localPath != null) {
      _resolvedArtworkUrl = Uri.file(localPath).toString();
      if (_currentSong?.id == song.id) _updateAllServices();
      return;
    }

    final coverArtId = song.coverArt!;

    // Search for cached artwork from highest to lowest quality for iOS Now Playing
    for (final sz in [1200, 800, 600, 400, 300, 200]) {
      for (final key in ['${coverArtId}_natural_$sz', '${coverArtId}_$sz']) {
        try {
          final fileInfo = await DefaultCacheManager().getFileFromCache(key);
          if (fileInfo != null && fileInfo.file.existsSync()) {
            if (_currentSong?.id == song.id) {
              _resolvedArtworkUrl = Uri.file(fileInfo.file.path).toString();
              _updateAllServices();
            }
            return;
          }
        } catch (_) {}
      }
    }
    // Request high quality for iOS Now Playing bar / Control Center (1200px)
    final serverUrl = _subsonicService.getCoverArtUrl(coverArtId, size: 1200);

    if (!_offlineService.isOfflineMode) {
      _resolvedArtworkUrl = serverUrl;
      if (_currentSong?.id == song.id) _updateAllServices();
    }
  }

  void _showFloatingWindowIfNeeded() {
    if (_currentSong == null) return;
    _externalMediaController.showFloatingWindow(
      title: _currentSong!.title,
      artist: _currentSong!.artist ?? '未知艺术家',
      isPlaying: _isPlaying,
    );
  }

  void _updateFloatingWindow() {
    if (_currentSong == null) return;
    _externalMediaController.updateFloatingWindow(
      title: _currentSong!.title,
      artist: _currentSong!.artist ?? '未知艺术家',
      isPlaying: _isPlaying,
    );
  }

  void hideFloatingWindow() {
    _externalMediaController.hideFloatingWindow();
  }

  bool get floatingWindowEnabled => _externalMediaController.floatingWindowEnabled;

  void setFloatingWindowEnabled(bool enabled) {
    _externalMediaController.setFloatingWindowEnabled(enabled);
    _storageService.saveFloatingWindowEnabled(enabled);
    if (!enabled) {
      _externalMediaController.hideFloatingWindow();
    }
    notifyListeners();
  }

  Future<void> requestFloatingWindowPermission() async {
    await _externalMediaController.requestFloatingWindowPermission();
  }

  bool get bootAutoStart => _bootAutoStart;

  Future<void> setBootAutoStart(bool enabled) async {
    _bootAutoStart = enabled;
    _bootAutoStartLoaded = true;
    await _storageService.saveBootAutoStart(enabled);
    notifyListeners();
  }

  void _updateAllServices() {
    if (_currentSong == null) return;

    final artworkUrl = _resolveArtworkUrl();

    final effectiveDuration = _duration.inMilliseconds > 0
        ? _duration
        : Duration(seconds: _currentSong!.duration ?? 0);

    _externalMediaController.updateNowPlaying(PlaybackSnapshot(
      song: _currentSong,
      artworkUrl: artworkUrl,
      duration: effectiveDuration,
      position: _position,
      isPlaying: _isPlaying,
      currentIndex: _currentIndex,
      queueLength: _queue.length,
      isRemotePlayback: _isRenderingRemotely,
    ));
  }

  void _updateAndroidAuto() {
    if (_currentSong == null) return;

    final artworkUrl = _resolveArtworkUrl();

    final effectiveDuration = _duration.inMilliseconds > 0
        ? _duration
        : Duration(seconds: _currentSong!.duration ?? 0);

    _externalMediaController.updateAndroidAuto(PlaybackSnapshot(
      song: _currentSong,
      artworkUrl: artworkUrl,
      duration: effectiveDuration,
      position: _position,
      isPlaying: _isPlaying,
      currentIndex: _currentIndex,
      queueLength: _queue.length,
      isRemotePlayback: _isRenderingRemotely,
    ));
  }

  bool get isSamsungDevice => _externalMediaController.isSamsungDevice;
  bool get isDexMode => _externalMediaController.isDexMode;
  bool get hasBluetoothDevice => _externalMediaController.hasBluetoothDevice;
  List<BluetoothDeviceInfo> get connectedBluetoothDevices =>
      _externalMediaController.connectedBluetoothDevices;

  List<Song> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;

  bool get isRemotePlayback => _isRenderingRemotely;
  bool get shuffleEnabled => _shuffleEnabled;
  bool get gaplessEnabled => _gaplessEnabled;
  RepeatMode get repeatMode => _repeatMode;
  Duration get position => _position;
  Duration get duration => _duration;
  Song? get currentSong => _currentSong;
  bool get hasNext =>
      _queue.isNotEmpty &&
      (_currentIndex < _queue.length - 1 ||
          _repeatMode == RepeatMode.all ||
          (_shuffleEnabled && _queue.length > 1));
  bool get hasPrevious =>
      _queue.isNotEmpty &&
      (_currentIndex > 0 ||
          _repeatMode == RepeatMode.all ||
          (_shuffleEnabled && _shuffleHistory.isNotEmpty));
  double get volume => _volume;

  RadioStation? get currentRadioStation => _currentRadioStation;
  bool get isPlayingRadio => _isPlayingRadio;

  final _positionController = StreamController<Duration>.broadcast();
  Stream<Duration> get positionStream => _positionController.stream;

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<int?>? _currentIndexSub;

  ConcatenatingAudioSource? _concatenatingSource;

  Timer? _windowsPositionTimer;
  Duration? _lastPolledPosition;

  double get progress {
    if (_duration.inMilliseconds == 0) return 0;
    return _position.inMilliseconds / _duration.inMilliseconds;
  }

  double get playbackSpeed => _playbackSpeed;
  double get pitch => _pitch;
  bool get pitchCorrection => _pitchCorrection;

  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed.clamp(0.25, 4.0);

    final targetPitch = _pitchCorrection ? 1.0 : _playbackSpeed;
    _pitch = targetPitch.clamp(0.5, 2.0);

    final success = await _audioHandler.setPlaybackParameters(
      _playbackSpeed,
      _pitch,
    );
    if (!success) {
      await _audioPlayer.setSpeed(_playbackSpeed);
    }

    notifyListeners();
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);

    final success = await _audioHandler.setPlaybackParameters(
      _playbackSpeed,
      _pitch,
    );
    if (!success) {
      await _audioPlayer.setSpeed(_playbackSpeed);
    }

    notifyListeners();
  }

  Future<void> togglePitchCorrection() async {
    _pitchCorrection = !_pitchCorrection;
    final targetPitch = _pitchCorrection ? 1.0 : _playbackSpeed;
    _pitch = targetPitch.clamp(0.5, 2.0);

    final success = await _audioHandler.setPlaybackParameters(
      _playbackSpeed,
      _pitch,
    );
    if (!success) {
      await _audioPlayer.setSpeed(_playbackSpeed);
    }

    notifyListeners();
  }

  bool get hasSleepTimer => _sleepTimerController.isActive;
  bool get sleepTimerEndCurrentSong => _sleepTimerController.endCurrentSong;
  bool get sleepTimerFadeOut => _sleepTimerController.fadeOutEnabled;
  int get sleepTimerFadeDurationSeconds => _sleepTimerController.fadeDurationSeconds;
  Duration? get sleepTimerRemaining => _sleepTimerController.remaining;

  void setSleepTimer(
    Duration duration, {
    bool endCurrentSong = false,
    bool fadeOut = false,
    int fadeDurationSeconds = 30,
  }) {
    _sleepTimerController.userVolume = _volume;
    _sleepTimerController.set(
      duration: duration,
      endCurrentSong: endCurrentSong,
      fadeOut: fadeOut,
      fadeDurationSeconds: fadeDurationSeconds,
    );
  }

  void _initializePlayer() {
    _configureAudioSession();

    // Load all persisted settings in parallel and notify once.
    Future.wait([
      _storageService.getVolume().then((savedVolume) {
        _volume = savedVolume;
        _audioPlayer.setVolume(_volume);
      }),
      _storageService.getShuffleMode().then((saved) {
        _shuffleEnabled = saved;
      }),
      _storageService.getRepeatMode().then((saved) {
        _repeatMode =
            RepeatMode.values[saved.clamp(0, RepeatMode.values.length - 1)];
      }),
      _storageService.getGaplessPlayback().then((saved) {
        _gaplessEnabled = saved;
      }),
      _storageService.getFloatingWindowEnabled().then((saved) {
        _externalMediaController.setFloatingWindowEnabled(saved);
        _floatingWindowEnabled = saved;
        _floatingWindowCacheLoaded = true;
      }),
      _storageService.getBootAutoStart().then((saved) {
        _bootAutoStart = saved;
        _bootAutoStartLoaded = true;
      }),
    ]).then((_) => notifyListeners()).catchError((e) {
      debugPrint('[Player] Error loading persisted settings: $e');
    });

    _playerStateSub = _audioPlayer.playerStateStream.listen(
      (state) {
        if (_isRenderingRemotely) return;

        final wasPlaying = _isPlaying;
        _isPlaying = state.playing;

        if (wasPlaying != _isPlaying && !_reactivatingSession) {
          debugPrint(
              '[Player] ${_isPlaying ? '▶ Playing' : '⏸ Paused'} — "${_currentSong?.title ?? 'unknown'}" (${state.processingState.name})');

          if (_isPlaying && Platform.isWindows && !_isRenderingRemotely) {
            _windowsPositionTimer?.cancel();
            _lastPolledPosition = null;
            _windowsPositionTimer = Timer.periodic(
              const Duration(milliseconds: 500),
              (_) {
                final pos = _audioPlayer.position;
                if (_lastPolledPosition == null ||
                    pos.inMilliseconds != _lastPolledPosition!.inMilliseconds) {
                  _lastPolledPosition = pos;
                  _position = pos;
                  _positionController.add(pos);
                  notifyListeners();
                  _updateAllServices();
                }
              },
            );
          } else {
            _windowsPositionTimer?.cancel();
            _windowsPositionTimer = null;
            _lastPolledPosition = null;
          }
        }

        if (state.processingState == ProcessingState.completed) {
          debugPrint(
              '[Player] ✓ Song completed: "${_currentSong?.title ?? 'unknown'}"');
          _onSongComplete().catchError(
              (e) => debugPrint('[Player] _onSongComplete error: $e'));
        }

        if (state.processingState == ProcessingState.buffering && !wasPlaying) {
          debugPrint(
              '[Player] ⟳ Buffering: "${_currentSong?.title ?? 'unknown'}"');
        }

        if (wasPlaying != _isPlaying && !_reactivatingSession) {
          notifyListeners();
          _updateAndroidAuto();
        }
      },
      onError: (error) {
        debugPrint('[Player] State stream error: $error');
      },
    );

    Duration? lastNotified;
    Duration? lastSystemUpdate;
    _positionSub = _audioPlayer.positionStream.listen(
      (position) {
        if (_isRenderingRemotely) return;

        final positionJumpedBack = _position.inMilliseconds > 0 &&
            position.inMilliseconds < _position.inMilliseconds - 1000;

        _position = position;
        _positionController.add(position);

        if (positionJumpedBack ||
            lastNotified == null ||
            position.inMilliseconds - lastNotified!.inMilliseconds > 250) {
          lastNotified = position;
          notifyListeners();
        }

        if (lastSystemUpdate == null ||
            (position.inMilliseconds - lastSystemUpdate!.inMilliseconds).abs() >
                1000) {
          lastSystemUpdate = position;
          _updateAllServices();
          _saveQueueState();
        }
      },
      onError: (error) {
        debugPrint('Position stream error: $error');
      },
    );

    _durationSub = _audioPlayer.durationStream.listen(
      (duration) {
        if (_isRenderingRemotely) return;

        _duration = duration ?? Duration.zero;
        notifyListeners();
        _updateAndroidAuto();
      },
      onError: (error) {
        debugPrint('Duration stream error: $error');
      },
    );

    _currentIndexSub = _audioPlayer.currentIndexStream.listen(
      (index) {
        if (index != null &&
            index != _currentIndex &&
            !_isRenderingRemotely &&
            _concatenatingSource != null) {
          _onCurrentIndexChanged(index).catchError((e) {
            debugPrint('[Player] _onCurrentIndexChanged error: $e');
          });
        }
      },
      onError: (error) {
        debugPrint('Current index stream error: $error');
      },
    );
  }

  Future<void> _configureAudioSession() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      debugPrint('[Player] AudioSession configured for music playback');

      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _audioPlayer.setVolume(0.3);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              if (isRemotePlayback) return;
              pause();
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _audioPlayer.setVolume(_volume);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              break;
          }
        }
      });

      session.becomingNoisyEventStream.listen((_) {
        if (isRemotePlayback) return;
        pause();
      });
    } catch (e) {
      debugPrint('[Player] AudioSession configuration failed: $e');
    }
  }

  Future<void> _ensureAudioFocus() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final granted = await _externalMediaController.requestAudioFocus();
      debugPrint('[Player] Audio focus requested, granted=$granted');
    } catch (e) {
      debugPrint('[Player] Audio focus request failed: $e');
    }
  }

  Future<void> _onSongComplete() async {
    if (_currentSong != null && _currentSong!.isLocal != true) {
      _subsonicService.scrobble(_currentSong!.id, submission: true).catchError((
        e,
      ) {
        _offlineService.queueScrobble(_currentSong!.id, submission: true);
      });
    }

    if (_currentSong != null && _recommendationService != null) {
      _recommendationService!.trackSongPlay(
        _currentSong!,
        durationPlayed: _duration.inSeconds,
        completed: true,
      );
    }

    // Call sleep timer's song completed logic
    _sleepTimerController.handleSongComplete();
    if (_sleepTimerController.endCurrentSong) {
      return;
    }

    if (_concatenatingSource != null) {
      await _handleEndOfQueue();
      return;
    }

    if (_repeatMode == RepeatMode.one ||
        (_repeatMode == RepeatMode.all && _queue.length == 1)) {
      await seek(Duration.zero);
      await play();
    } else if (_currentIndex < _queue.length - 1 ||
        _repeatMode == RepeatMode.all ||
        _shuffleEnabled) {
      await skipNext();
    } else {
      await _handleEndOfQueue();
    }
  }

  Future<void> _handleEndOfQueue() async {
    if (_autoDjService.isEnabled) {
      await _addAutoDjSongs();

      if (_currentIndex < _queue.length - 1) {
        await skipToIndex(_currentIndex + 1);
      }
    }
  }

  Future<void> playSong(
    Song song, {
    List<Song>? playlist,
    int? startIndex,
  }) async {
    if (_currentSong?.id == song.id && !_isPlayingRadio) {
      await togglePlayPause();
      return;
    }

    _isPlayingRadio = false;
    _currentRadioStation = null;

    if (_jukeboxService.enabled) {
      final targetPlaylist = (playlist ?? [song]).toList();
      final targetIndex = startIndex ??
          targetPlaylist
              .indexWhere((s) => s.id == song.id)
              .clamp(0, targetPlaylist.length - 1);
      await _jukeboxService.setQueue(
        _subsonicService,
        targetPlaylist,
        startIndex: targetIndex,
      );
      _isPlaying = true;
      _isLoading = false;
      notifyListeners();
      _updateAllServices();
      _updateAndroidAuto();
      return;
    }

    debugPrint(
        '[Player] playSong: "${song.title}"');
    _isLoading = true;
    notifyListeners();

    try {
      if (playlist != null) {
        final isNewQueue = !identical(playlist, _queue);
        _queue = List.from(playlist);
        _currentIndex =
            startIndex ?? playlist.indexWhere((s) => s.id == song.id);
        if (_currentIndex == -1) _currentIndex = 0;
        if (isNewQueue) _shuffleHistory.clear();
      } else if (_queue.isEmpty || !_queue.any((s) => s.id == song.id)) {
        _queue = [song];
        _currentIndex = 0;
        _shuffleHistory.clear();
      } else {
        _currentIndex = _queue.indexWhere((s) => s.id == song.id);
      }

      _currentSong = song;
      _resolvedArtworkUrl = null;
      _position = Duration.zero;
      notifyListeners();
      _saveQueueState();

      await _refreshArtworkUrl();

      await _lyricsService.updateSongInfo(
        title: song.title,
        artist: song.artist ?? 'Unknown Artist',
        artworkUrl: _resolvedArtworkUrl ?? song.coverArt,
      );

      if (_castService.isConnected) {
        if (_audioPlayer.playing) await _audioPlayer.stop();

        final playUrl = song.isLocal == true
            ? Uri.file(song.path!).toString()
            : await _subsonicService.resolveStreamUrlAsync(song);
        final coverUrl = song.isLocal == true && song.coverArt != null
            ? song.coverArt!
            : _subsonicService.getCoverArtUrl(song.coverArt ?? song.id);

        await _castService.loadMedia(
          url: playUrl,
          title: song.title,
          artist: song.artist ?? 'Unknown Artist',
          imageUrl: coverUrl,
          albumName: song.album,
          trackNumber: song.track,
          duration:
              song.duration != null ? Duration(seconds: song.duration!) : null,
          autoPlay: true,
        );
        _isRenderingRemotely = true;
        _isPlaying = true;
      } else if (_upnpService.isConnected) {
        _upnpWasPlaying = false;
        if (_audioPlayer.playing) await _audioPlayer.stop();

        final playUrl = song.isLocal == true && song.path != null
            ? Uri.file(song.path!).toString()
            : await _subsonicService.resolveStreamUrlAsync(song);

        try {
          final mimeType =
              song.contentType ?? UpnpService.mimeTypeFromSuffix(song.suffix);
          final success = await _upnpService.loadAndPlay(
            url: playUrl,
            title: song.title,
            artist: song.artist ?? 'Unknown Artist',
            album: song.album,
            albumArtUrl: song.coverArt != null
                ? _subsonicService.getCoverArtUrl(song.coverArt, size: 0)
                : null,
            durationSecs: song.duration,
            contentType: mimeType,
          );
          if (!success) {
            _upnpService.disconnect();
            return;
          }
        } catch (e) {
          _upnpService.disconnect();
          rethrow;
        }
        _isRenderingRemotely = true;
        _isPlaying = true;
      } else {
        _isRenderingRemotely = false;

        final youtubeSource = song.isLocal != true
            ? await _subsonicService.getYoutubeAudioSource(song)
            : null;

        if (youtubeSource != null) {
          await _audioPlayer.setAudioSource(youtubeSource);
          await _applyReplayGain(song);
          await _ensureAudioFocus();
          await _audioPlayer.play();
        } else if (_subsonicService.isYoutube) {
          final String playUrl;
          if (song.isLocal == true && song.path != null) {
            playUrl = Uri.file(song.path!).toString();
          } else {
            final offlinePath = _offlineService.getLocalPath(song.id);
            if (offlinePath != null) {
              playUrl = 'file://$offlinePath';
            } else {
              playUrl = await _subsonicService.resolveStreamUrlAsync(song);
            }
          }
          await _audioPlayer.setUrl(playUrl);
          await _applyReplayGain(song);
          await _ensureAudioFocus();
          await _audioPlayer.play();
        } else if (_gaplessEnabled) {
          try {
            await _buildAndSetConcatenatingSource(initialIndex: _currentIndex);
          } catch (e) {
            if (!_hasPlayedOnce) {
              await Future.delayed(const Duration(milliseconds: 100));
              await _buildAndSetConcatenatingSource(
                  initialIndex: _currentIndex);
              _hasPlayedOnce = true;
            } else {
              rethrow;
            }
          }
          await _applyReplayGain(song);
          await _ensureAudioFocus();
          await _audioPlayer.play();
        } else {
          final String playUrl;
          if (song.isLocal == true && song.path != null) {
            playUrl = Uri.file(song.path!).toString();
          } else {
            final offlinePath = _offlineService.getLocalPath(song.id);
            if (offlinePath != null) {
              playUrl = 'file://$offlinePath';
            } else {
              final maxBitRate = _transcodingService.enabled
                  ? _transcodingService.currentBitRate
                  : null;
              final format = _transcodingService.enabled
                  ? _transcodingService.format
                  : null;
              playUrl = _subsonicService.getStreamUrl(song.id,
                  maxBitRate: maxBitRate, format: format);
            }
          }
          if (song.isLocal == true ||
              _offlineService.getLocalPath(song.id) != null) {
            await _audioPlayer.setUrl(playUrl);
          } else {
            final cacheDir = await getTemporaryDirectory();
            final cacheFile = File(
              '${cacheDir.path}/musly_stream_${song.id.hashCode}.tmp',
            );
            await _audioPlayer.setAudioSource(
              LockCachingAudioSource(
                Uri.parse(playUrl),
                cacheFile: cacheFile,
                tag: song.id,
              ),
            );
          }
          await _applyReplayGain(song);
          await _ensureAudioFocus();
          await _audioPlayer.play();
        }
      }

      if (song.isLocal != true) {
        if (_offlineService.isOfflineMode) {
          _offlineService.queueScrobble(song.id, submission: false);
        } else {
          _subsonicService.scrobble(song.id, submission: false).catchError((e) {
            _offlineService.queueScrobble(song.id, submission: false);
          });

          _offlineService
              .flushPendingScrobbles(_subsonicService)
              .catchError((e) {
            debugPrint('Scrobble flush failed: $e');
          });
        }
      }

      if (_recommendationService != null) {
        _recommendationService!.trackSongPlay(
          song,
          durationPlayed: 0,
          completed: false,
        );
      }

      _updateAndroidAuto();
    } catch (e) {
      debugPrint('[Player] Error playing song "${song.title}": $e');
      _isPlaying = false;
      _position = Duration.zero;
      _updateAndroidAuto();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> playRadioStation(RadioStation station) async {
    if (_isPlayingRadio && _currentRadioStation?.id == station.id) {
      await togglePlayPause();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _currentSong = null;
      _queue = [];
      _currentIndex = -1;
      _isPlayingRadio = true;
      _isRenderingRemotely = false; // radio always plays locally
      _currentRadioStation = station;
      _position = Duration.zero;
      _duration = Duration.zero;

      try {
        await _audioPlayer.setUrl(station.streamUrl);
      } catch (e) {
        if (!_hasPlayedOnce) {
          await Future.delayed(const Duration(milliseconds: 100));
          await _audioPlayer.setUrl(station.streamUrl);
          _hasPlayedOnce = true;
        } else {
          rethrow;
        }
      }

      await _audioPlayer.setVolume(_volume);

      await _ensureAudioFocus();
      await _audioPlayer.play();

      _externalMediaController.updateForRadio(station);

      // Show floating window for radio (if enabled)
      if (Platform.isAndroid) {
        final enabled = _externalMediaController.floatingWindowEnabled;
        if (enabled) {
          _externalMediaController.showFloatingWindow(
            title: station.name,
            artist: '网络电台',
            isPlaying: true,
          );
        }
      }
    } catch (e) {
      debugPrint('Error playing radio station: $e');
      _isPlaying = false;
      _isPlayingRadio = false;
      _currentRadioStation = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void stopRadio() {
    if (_isPlayingRadio) {
      _audioPlayer.stop();
      _isPlayingRadio = false;
      _currentRadioStation = null;
      _isPlaying = false;
      _lyricsService.stopSync();
      _lyricsService.loadLyrics(null);
      _externalMediaController.hideFloatingWindow();
      notifyListeners();
    }
  }

  Future<void> play() async {
    if (_jukeboxService.enabled) {
      await _jukeboxService.play(_subsonicService);
      _isPlaying = true;
      notifyListeners();
      _updateAndroidAuto();
      return;
    }
    if (_castService.isConnected) {
      await _castService.play();
      _isPlaying = true;
      notifyListeners();
      _updateAndroidAuto();
    } else if (_upnpService.isConnected) {
      await _upnpService.play();
      _isPlaying = true;
      notifyListeners();
      _updateAndroidAuto();
    } else {
      if (_currentSong != null &&
          (_audioPlayer.audioSource == null ||
              _audioPlayer.duration == Duration.zero)) {
        await _prepareCurrentSong();
      }
      await _ensureAudioFocus();
      await _audioPlayer.play();
      await _fadeIn();
    }
  }

  Future<void> pause() async {
    if (_jukeboxService.enabled) {
      await _jukeboxService.pause(_subsonicService);
      _isPlaying = false;
      notifyListeners();
      _updateAndroidAuto();
      _updateFloatingWindow();
      return;
    }
    if (_castService.isConnected) {
      await _castService.pause();
      _isPlaying = false;
      notifyListeners();
      _updateAndroidAuto();
      _updateFloatingWindow();
    } else if (_upnpService.isConnected) {
      await _upnpService.pause();
      _isPlaying = false;
      notifyListeners();
      _updateAndroidAuto();
      _updateFloatingWindow();
    } else {
      await _fadeOut(onComplete: () async {
        await _audioPlayer.pause();
      });
      _isPlaying = false;
      notifyListeners();
      _updateAndroidAuto();
    }
  }

  Future<void> stop() async {
    if (_castService.isConnected) {
      await _castService.stop();
    } else if (_upnpService.isConnected) {
      _upnpWasPlaying = false;
      await _upnpService.stop();
    } else {
      await _audioPlayer.stop();
    }

    _isPlaying = false;
    _position = Duration.zero;
    notifyListeners();
    _updateAndroidAuto();
    _externalMediaController.hideFloatingWindow();
  }

  // ── Fade In/Out ────────────────────────────────────────────────────────────

  void _stopFade() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _isFading = false;
  }

  Future<void> _fadeIn() async {
    _stopFade();

    if (!_fadeSettingsService.getFadeEnabled()) {
      await _audioPlayer.setVolume(_volume);
      return;
    }

    final fadeDurationMs = _fadeSettingsService.getFadeDurationMs();
    final steps = 20;
    final stepDurationMs = fadeDurationMs ~/ steps;
    final volumeStep = _volume / steps;

    _isFading = true;
    await _audioPlayer.setVolume(0.0);

    var currentStep = 0;
    _fadeTimer =
        Timer.periodic(Duration(milliseconds: stepDurationMs), (timer) async {
      if (!_isFading || currentStep >= steps) {
        timer.cancel();
        _isFading = false;
        return;
      }
      currentStep++;
      final newVolume = volumeStep * currentStep;
      await _audioPlayer.setVolume(newVolume.clamp(0.0, _volume));
    });
  }

  Future<void> _fadeOut({VoidCallback? onComplete}) async {
    _stopFade();

    if (!_fadeSettingsService.getFadeEnabled()) {
      await _audioPlayer.setVolume(0.0);
      onComplete?.call();
      return;
    }

    final fadeDurationMs = _fadeSettingsService.getFadeDurationMs();
    final steps = 20;
    final stepDurationMs = fadeDurationMs ~/ steps;
    final currentVolume = _audioPlayer.volume;
    final volumeStep = currentVolume / steps;

    _isFading = true;

    var currentStep = 0;
    _fadeTimer =
        Timer.periodic(Duration(milliseconds: stepDurationMs), (timer) async {
      if (!_isFading || currentStep >= steps) {
        timer.cancel();
        _isFading = false;
        onComplete?.call();
        return;
      }
      currentStep++;
      final newVolume = currentVolume - (volumeStep * currentStep);
      await _audioPlayer.setVolume(newVolume.clamp(0.0, 1.0));
    });
  }

  void _smoothVolumeChange(double targetVolume, {int durationMs = 150}) {
    _stopFade();

    final currentVolume = _audioPlayer.volume;
    if ((currentVolume - targetVolume).abs() < 0.01) return;

    final steps = 10;
    final stepDurationMs = durationMs ~/ steps;
    final volumeDiff = targetVolume - currentVolume;
    final volumeStep = volumeDiff / steps;

    _isFading = true;

    var currentStep = 0;
    _fadeTimer =
        Timer.periodic(Duration(milliseconds: stepDurationMs), (timer) async {
      if (!_isFading || currentStep >= steps) {
        timer.cancel();
        _isFading = false;
        return;
      }
      currentStep++;
      final newVolume = currentVolume + (volumeStep * currentStep);
      await _audioPlayer.setVolume(newVolume.clamp(0.0, 1.0));
    });
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seek(Duration position) async {
    _position = position;
    notifyListeners();
    if (_jukeboxService.enabled) {
      return;
    }
    if (_castService.isConnected) {
      await _castService.seek(position);
    } else if (_upnpService.isConnected) {
      await _upnpService.seek(position);
    } else {
      await _audioPlayer.seek(position);
    }
  }

  Future<void> seekToProgress(double progress) async {
    final position = Duration(
      milliseconds: (progress * _duration.inMilliseconds).round(),
    );
    await seek(position);
  }

  Future<void> skipNext() async {
    if (_currentSong != null && _recommendationService != null) {
      final played = _position.inSeconds;
      final total = _duration.inSeconds;
      if (total > 0 && played < total * 0.8) {
        _recommendationService!.trackSkip(_currentSong!);
      } else if (played > 0) {
        _recommendationService!.trackSongPlay(
          _currentSong!,
          durationPlayed: played,
          completed: played >= total * 0.8,
        );
      }
    }

    if (_jukeboxService.enabled) {
      await _jukeboxService.skipNext(_subsonicService);
      return;
    }

    if (_autoDjService.shouldAddSongs(_currentIndex, _queue.length)) {
      await _addAutoDjSongs();
    }

    if (_concatenatingSource != null) {
      if (_shuffleEnabled && _queue.length > 1) {
        _shuffleHistory.add(_currentSong!.id);
        if (_shuffleHistory.length > 50) _shuffleHistory.removeAt(0);
        int next;
        do {
          next = Random().nextInt(_queue.length);
        } while (next == _currentIndex);
        await _audioPlayer.seek(Duration.zero, index: next);
      } else if (_currentIndex < _queue.length - 1) {
        await _audioPlayer.seek(Duration.zero, index: _currentIndex + 1);
      } else if (_repeatMode == RepeatMode.all) {
        await _audioPlayer.seek(Duration.zero, index: 0);
      }
      return;
    }

    if (_shuffleEnabled && _queue.length > 1) {
      _shuffleHistory.add(_currentSong!.id);
      if (_shuffleHistory.length > 50) _shuffleHistory.removeAt(0);
      int next;
      do {
        next = Random().nextInt(_queue.length);
      } while (next == _currentIndex);
      await skipToIndex(next);
    } else if (_currentIndex < _queue.length - 1) {
      await skipToIndex(currentIndex + 1);
    } else if (_repeatMode == RepeatMode.all) {
      if (_queue.length == 1) {
        await seek(Duration.zero);
        await play();
      } else {
        await skipToIndex(0);
      }
    }
  }

  Future<void> _addAutoDjSongs() async {
    if (!_autoDjService.isEnabled) return;

    try {
      final songsToAdd = await _autoDjService.getSongsToQueue(
        currentSong: _currentSong,
        currentQueue: _queue,
        availableSongs: _libraryProvider?.cachedAllSongs,
      );

      if (songsToAdd.isNotEmpty) {
        _queue.addAll(songsToAdd);
        if (_concatenatingSource != null) {
          for (final song in songsToAdd) {
            try {
              final source = await _buildAudioSourceForSong(song);
              _concatenatingSource!.add(source);
            } catch (e) {
              debugPrint('Error adding AutoDJ song to concatenating source: $e');
            }
          }
        }
        notifyListeners();
        _saveQueueState();
      }
    } catch (e) {
      debugPrint('Auto DJ error: $e');
    }
  }

  Future<void> skipPrevious() async {
    if (_jukeboxService.enabled) {
      await _jukeboxService.skipPrevious(_subsonicService);
      return;
    }
    if (_position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    if (_concatenatingSource != null) {
      if (_shuffleEnabled && _shuffleHistory.isNotEmpty) {
        final prevId = _shuffleHistory.removeLast();
        final prev = _queue.indexWhere((s) => s.id == prevId);
        if (prev != -1) {
          await _audioPlayer.seek(Duration.zero, index: prev);
          return;
        }
      }
      if (_currentIndex > 0) {
        await _audioPlayer.seek(Duration.zero, index: _currentIndex - 1);
      } else if (_repeatMode == RepeatMode.all && _queue.isNotEmpty) {
        await _audioPlayer.seek(Duration.zero, index: _queue.length - 1);
      } else {
        await seek(Duration.zero);
      }
      return;
    }

    if (_shuffleEnabled && _shuffleHistory.isNotEmpty) {
      final prevId = _shuffleHistory.removeLast();
      final prev = _queue.indexWhere((s) => s.id == prevId);
      if (prev != -1) await skipToIndex(prev);
    } else if (_currentIndex > 0) {
      await skipToIndex(_currentIndex - 1);
    } else if (_repeatMode == RepeatMode.all && _queue.isNotEmpty) {
      if (_queue.length == 1) {
        await seek(Duration.zero);
        await play();
      } else {
        await skipToIndex(_queue.length - 1);
      }
    } else {
      await seek(Duration.zero);
    }
  }

  Future<void> skipToIndex(int index) async {
    if (index >= 0 && index < _queue.length) {
      if (_concatenatingSource != null) {
        await _audioPlayer.seek(Duration.zero, index: index);
      } else {
        await playSong(_queue[index], playlist: _queue, startIndex: index);
      }
    }
  }

  void toggleShuffle() {
    _shuffleEnabled = !_shuffleEnabled;
    _shuffleHistory.clear();
    if (_shuffleEnabled && _queue.length > 1 && _currentSong != null) {
      final currentSong = _currentSong!;
      _queue.shuffle();
      _queue.remove(currentSong);
      _queue.insert(0, currentSong);
      _currentIndex = 0;
      if (_concatenatingSource != null) {
        _buildAndSetConcatenatingSource(initialIndex: 0).catchError((e) {
          debugPrint('Error rebuilding concatenating source after shuffle: $e');
        });
      }
      _saveQueueState();
    }
    _storageService.saveShuffleMode(_shuffleEnabled);
    notifyListeners();
  }

  void toggleRepeat() {
    switch (_repeatMode) {
      case RepeatMode.off:
        _repeatMode = RepeatMode.all;
        _audioPlayer.setLoopMode(LoopMode.all);
        break;
      case RepeatMode.all:
        _repeatMode = RepeatMode.one;
        _audioPlayer.setLoopMode(LoopMode.one);
        break;
      case RepeatMode.one:
        _repeatMode = RepeatMode.off;
        _audioPlayer.setLoopMode(LoopMode.off);
        break;
    }
    _storageService.saveRepeatMode(_repeatMode.index);
    notifyListeners();
  }

  void toggleGaplessPlayback() {
    _gaplessEnabled = !_gaplessEnabled;
    _storageService.saveGaplessPlayback(_gaplessEnabled);
    notifyListeners();
  }

  void addToQueue(Song song) {
    _queue.add(song);
    notifyListeners();
  }

  Future<void> addToQueueNext(Song song) async {
    final insertIndex = _currentIndex + 1;
    if (insertIndex < _queue.length) {
      _queue.insert(insertIndex, song);
    } else {
      _queue.add(song);
    }
    if (_concatenatingSource != null) {
      try {
        final audioSource = await _buildAudioSourceForSong(song);
        if (insertIndex < _concatenatingSource!.length) {
          _concatenatingSource!.insert(insertIndex, audioSource);
        } else {
          _concatenatingSource!.add(audioSource);
        }
      } catch (e) {
        debugPrint('Error adding to concatenating source: $e');
      }
    }
    notifyListeners();
  }

  Future<void> addAllToQueue(Iterable<Song> songs) async {
    final newSongs = songs.toList();
    _queue.addAll(newSongs);
    if (_concatenatingSource != null) {
      for (final song in newSongs) {
        try {
          final source = await _buildAudioSourceForSong(song);
          _concatenatingSource!.add(source);
        } catch (e) {
          debugPrint('Error adding to concatenating source: $e');
        }
      }
    }
    notifyListeners();
  }

  void removeFromQueue(int index) {
    if (index >= 0 && index < _queue.length) {
      _queue.removeAt(index);
      if (_concatenatingSource != null &&
          index < _concatenatingSource!.length) {
        try {
          _concatenatingSource!.removeAt(index);
        } catch (e) {
          debugPrint('Error removing from concatenating source: $e');
        }
      }
      if (index < _currentIndex) {
        _currentIndex--;
      } else if (index == _currentIndex && _queue.isNotEmpty) {
        if (_currentIndex >= _queue.length) {
          _currentIndex = _queue.length - 1;
        }
        if (_queue.isNotEmpty) {
          playSong(
            _queue[_currentIndex],
            playlist: _queue,
            startIndex: _currentIndex,
          );
        }
      }
      _saveQueueState();
      notifyListeners();
    }
  }

  void clearQueue() {
    _queue.clear();
    _currentIndex = -1;
    _currentSong = null;
    _concatenatingSource = null;
    _externalMediaController.clearDiscordPresence();
    try {
      _lyricsService.stopSync();
    } catch (_) {}
    _clearPersistedQueue();
    try {
      _lyricsService.loadLyrics(null);
    } catch (_) {}
    _audioPlayer.stop();
    _isPlaying = false;
    _position = Duration.zero;
    notifyListeners();
    _updateAndroidAuto();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final song = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, song);

    if (_concatenatingSource != null) {
      try {
        _concatenatingSource!.move(oldIndex, newIndex);
      } catch (e) {
        debugPrint('Error moving in concatenating source: $e');
      }
    }

    if (oldIndex == _currentIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex -= 1;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex += 1;
    }

    notifyListeners();
    _saveQueueState();
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _storageService.saveVolume(_volume);
    if (_castService.isConnected) {
      await _castService.setVolume(_volume);
    } else if (_upnpService.isConnected) {
      await _upnpService.setVolume((_volume * 100).round());
    } else {
      await _applyReplayGain(_currentSong);
    }
    notifyListeners();
  }

  bool _upnpVolumeWriteInProgress = false;

  void _onRemoteVolumeChange(int volume) {
    if (_castService.isConnected) {
      _castService.setVolume(volume / 100.0);
    } else if (_upnpService.isConnected) {
      if (_upnpVolumeWriteInProgress) return;
      _applyUpnpVolume(volume);
    }
  }

  Future<void> _applyUpnpVolume(int volume) async {
    _upnpVolumeWriteInProgress = true;
    _volume = (volume / 100.0).clamp(0.0, 1.0);
    notifyListeners();
    try {
      await _upnpService.setVolume(volume);
      final actual = await _upnpService.getVolume();
      if (actual >= 0) {
        _volume = actual / 100.0;
        _externalMediaController.updateRemoteVolume(actual);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('UPnP setVolume error: $e');
    } finally {
      _upnpVolumeWriteInProgress = false;
    }
  }

  // ── Gapless playback helpers ───────────────────────────────────────────

  Future<AudioSource> _buildAudioSourceForSong(Song song) async {
    if (song.isLocal == true && song.path != null) {
      return AudioSource.uri(Uri.file(song.path!));
    }
    final offlinePath = _offlineService.getLocalPath(song.id);
    if (offlinePath != null) {
      return AudioSource.uri(Uri.file(offlinePath));
    }
    final maxBitRate =
        _transcodingService.enabled ? _transcodingService.currentBitRate : null;
    final format =
        _transcodingService.enabled ? _transcodingService.format : null;
    final url = _subsonicService.getStreamUrl(song.id,
        maxBitRate: maxBitRate, format: format);
    final cacheDir = await getTemporaryDirectory();
    final cacheFile = File(
      '${cacheDir.path}/musly_stream_${song.id.hashCode}.tmp',
    );
    return LockCachingAudioSource(
      Uri.parse(url),
      cacheFile: cacheFile,
      tag: song.id,
    );
  }

  Future<void> _buildAndSetConcatenatingSource(
      {required int initialIndex}) async {
    final children = await Future.wait(_queue.map(_buildAudioSourceForSong));
    _concatenatingSource = ConcatenatingAudioSource(children: children);
    await _audioPlayer.setAudioSource(
      _concatenatingSource!,
      initialIndex: initialIndex,
      preload: true,
    );
  }

  Future<void> _prepareCurrentSong() async {
    if (_currentSong == null) return;
    if (_jukeboxService.enabled) return;
    try {
      if (_gaplessEnabled && _queue.isNotEmpty) {
        await _buildAndSetConcatenatingSource(initialIndex: _currentIndex);
      } else {
        final String playUrl;
        if (_currentSong!.isLocal == true && _currentSong!.path != null) {
          playUrl = Uri.file(_currentSong!.path!).toString();
        } else {
          final offlinePath = _offlineService.getLocalPath(_currentSong!.id);
          if (offlinePath != null) {
            playUrl = 'file://$offlinePath';
          } else {
            playUrl =
                await _subsonicService.resolveStreamUrlAsync(_currentSong!);
          }
        }
        if (_currentSong!.isLocal == true ||
            _offlineService.getLocalPath(_currentSong!.id) != null) {
          await _audioPlayer.setUrl(playUrl);
        } else {
          final cacheDir = await getTemporaryDirectory();
          final cacheFile = File(
            '${cacheDir.path}/musly_stream_${_currentSong!.id.hashCode}.tmp',
          );
          await _audioPlayer.setAudioSource(
            LockCachingAudioSource(
              Uri.parse(playUrl),
              cacheFile: cacheFile,
              tag: _currentSong!.id,
            ),
          );
        }
      }
      if (_position.inMilliseconds > 0) {
        await _audioPlayer.seek(_position);
      }
    } catch (e) {
      debugPrint('Error preparing current song after restore: $e');
    }
  }

  Future<void> _onCurrentIndexChanged(int newIndex) async {
    if (newIndex < 0 || newIndex >= _queue.length) return;
    if (newIndex == _currentIndex) return;

    debugPrint(
        '[Player] Track changed by index: $newIndex "${_queue[newIndex].title}"');

    _sleepTimerController.handleSongComplete();
    if (_sleepTimerController.endCurrentSong) {
      return;
    }

    if (_currentSong != null) {
      if (_currentSong!.isLocal != true) {
        _subsonicService
            .scrobble(_currentSong!.id, submission: true)
            .catchError(
          (e) {
            _offlineService.queueScrobble(_currentSong!.id, submission: true);
          },
        );
      }
      if (_recommendationService != null) {
        _recommendationService!.trackSongPlay(
          _currentSong!,
          durationPlayed: _duration.inSeconds,
          completed: true,
        );
      }
    }

    if (_autoDjService.shouldAddSongs(newIndex, _queue.length)) {
      await _addAutoDjSongs();
    }

    _currentIndex = newIndex;
    _currentSong = _queue[_currentIndex];
    _position = Duration.zero;
    _resolvedArtworkUrl = null;
    notifyListeners();
    _saveQueueState();

    await _refreshArtworkUrl();
    if (_currentSong != null) {
      await _lyricsService.updateSongInfo(
        title: _currentSong!.title,
        artist: _currentSong!.artist ?? 'Unknown Artist',
        artworkUrl: _resolvedArtworkUrl ?? _currentSong!.coverArt,
      );
      await _applyReplayGain(_currentSong);
    }

    _updateAllServices();
    _updateAndroidAuto();
  }

  Future<void> _applyReplayGain(Song? song) async {
    await _replayGainService.initialize();

    final replayGainMultiplier = _replayGainService.calculateVolumeMultiplier(
      trackGain: song?.replayGainTrackGain,
      albumGain: song?.replayGainAlbumGain,
      trackPeak: song?.replayGainTrackPeak,
      albumPeak: song?.replayGainAlbumPeak,
    );

    final effectiveVolume = _volume * replayGainMultiplier;
    await _audioPlayer.setVolume(effectiveVolume);
  }

  Future<void> refreshReplayGain() async {
    await _applyReplayGain(_currentSong);
    notifyListeners();
  }

  ReplayGainService get replayGainService => _replayGainService;

  Future<void> toggleFavorite() async {
    if (_currentSong == null) return;

    final isStarred = _currentSong!.starred == true;

    final newSong = _currentSong!.copyWith(starred: !isStarred);
    _currentSong = newSong;
    notifyListeners();

    try {
      if (isStarred) {
        await _subsonicService.unstar(id: newSong.id);
      } else {
        await _subsonicService.star(id: newSong.id);
      }
      _libraryProvider?.loadStarred();
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      _currentSong = _currentSong!.copyWith(starred: isStarred);
      notifyListeners();
    }
  }

  Future<void> toggleFavoriteForSong(Song song) async {
    final isStarred = song.starred == true;
    try {
      if (isStarred) {
        await _subsonicService.unstar(id: song.id);
      } else {
        await _subsonicService.star(id: song.id);
      }
      _libraryProvider?.loadStarred();

      if (_currentSong?.id == song.id) {
        _currentSong = _currentSong!.copyWith(starred: !isStarred);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error toggling favorite for song: $e');
    }
  }

  Future<void> setRating(String songId, int rating) async {
    if (_currentSong?.id != songId) return;

    final previousRating = _currentSong?.userRating;
    _currentSong = _currentSong?.copyWith(userRating: rating);
    notifyListeners();

    try {
      await _subsonicService.setRating(songId, rating);
    } catch (e) {
      _currentSong = _currentSong?.copyWith(userRating: previousRating);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> reactivateAudioSession() async {
    await _externalMediaController.requestAudioFocus();

    if (_currentSong != null) {
      _updateAllServices();
    }

    if (Platform.isIOS) {
      try {
        final session = await AudioSession.instance;
        await session.setActive(true);

        await Future.delayed(const Duration(milliseconds: 100));

        if (_currentSong != null && !_audioPlayer.playing) {
          debugPrint(
              '[Player] iOS: Resuming playback after audio session reactivation');
          await _audioPlayer.play();
          _isPlaying = true;
          notifyListeners();
          _updateAllServices();
        }
      } catch (e) {
        debugPrint('[Player] iOS: Error reactivating audio session: $e');
      }
    }
  }

  @override
  void dispose() {
    _sleepTimerController.dispose();
    _saveQueueStateImmediate();
    _queuePersistence.dispose();
    _jukeboxPollTimer?.cancel();
    _jukeboxService.removeListener(_onJukeboxEnabledChanged);
    _windowsPositionTimer?.cancel();
    _castService.removeListener(_onCastStateChanged);
    _upnpService.removeListener(_onUpnpStateChanged);
    if (_upnpService.onRendererLost == _onUpnpRendererLost) {
      _upnpService.onRendererLost = null;
    }
    _audioPlayer.stop().catchError((_) {});

    _audioHandler.customAction('dispose').catchError((e) {
      debugPrint('Error disposing audio handler: $e');
    });

    _externalMediaController.dispose();

    try {
      _lyricsService.dispose();
    } catch (_) {}

    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _currentIndexSub?.cancel();
    _positionController.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool get discordRpcEnabled => _externalMediaController.discordRpcEnabled;
  String get discordRpcStateStyle => _externalMediaController.discordRpcStateStyle;

  Future<void> setDiscordRpcEnabled(bool enabled) async {
    await _externalMediaController.setDiscordRpcEnabled(enabled);
  }

  Future<void> setDiscordRpcStateStyle(String style) async {
    await _externalMediaController.setDiscordRpcStateStyle(style, _storageService);
    _updateAndroidAuto();
    notifyListeners();
  }

  void _onCastStateChanged() {
    notifyListeners();
    if (_castService.isConnected) {
      _audioPlayer.pause();
      _externalMediaController.setRemotePlayback(isRemote: true, volume: 50);
      if (_currentSong != null) {
        final song = _currentSong!;
        _currentSong = null;
        playSong(song);
      }
    } else {
      _isRenderingRemotely = false;
      _externalMediaController.setRemotePlayback(isRemote: false);
      _isPlaying = false;
      notifyListeners();
      _updateAndroidAuto();
    }
  }

  bool _upnpWasConnected = false;
  bool _upnpWasPlaying = false;

  void _onUpnpStateChanged() {
    final connected = _upnpService.isConnected;

    if (connected && !_upnpWasConnected) {
      _upnpWasConnected = true;
      _upnpWasPlaying = false;
      if (_audioPlayer.playing) _audioPlayer.pause();
      final vol = _upnpService.volume;

      if (vol >= 0) _volume = vol / 100.0;
      _externalMediaController.setRemotePlayback(
        isRemote: true,
        volume: vol >= 0 ? vol : 50,
      );
      if (_currentSong != null) {
        final song = _currentSong!;
        _currentSong = null;
        playSong(song);
      }
      return;
    }

    if (!connected && _upnpWasConnected) {
      _upnpWasConnected = false;
      _upnpWasPlaying = false;
      _isRenderingRemotely = false;
      _isPlaying = false;
      _externalMediaController.setRemotePlayback(isRemote: false);
      notifyListeners();
      _updateAndroidAuto();
      return;
    }

    if (!connected) return;

    final pos = _upnpService.rendererPosition;
    final dur = _upnpService.rendererDuration;
    final playing = _upnpService.isRendererPlaying;
    final rendererState = _upnpService.rendererState;

    if (_upnpWasPlaying && rendererState == 'STOPPED') {
      debugPrint(
          'UPnP: Track ended — advancing');
      _upnpWasPlaying = false;
      _onSongComplete()
          .catchError((e) => debugPrint('[Player] _onSongComplete error: $e'));
      return;
    }

    _upnpWasPlaying = playing;

    bool changed = false;

    if ((_position - pos).abs() > const Duration(milliseconds: 500)) {
      _position = pos;
      changed = true;
    }
    if (dur != _duration) {
      _duration = dur;
      changed = true;
    }
    if (playing != _isPlaying) {
      _isPlaying = playing;
      changed = true;
    }

    final vol = _upnpService.volume;
    if (vol >= 0 && !_upnpVolumeWriteInProgress) {
      final normalized = vol / 100.0;
      if ((_volume - normalized).abs() > 0.005) {
        _volume = normalized;
        changed = true;
        _externalMediaController.updateRemoteVolume(vol);
      }
    }

    if (changed) {
      _positionController.add(_position);
      notifyListeners();
      _updateAndroidAuto();
    }
  }

  Future<void> _onUpnpRendererLost() async {
    final lastPosition = _position;
    final lastSong = _currentSong;

    debugPrint(
      'UPnP: renderer lost — A2DP audio active: $_isA2dpAudioActive, '
      'last position: ${lastPosition.inSeconds}s, song: "${lastSong?.title}"',
    );

    if (lastSong == null) return;

    final playUrl = lastSong.isLocal == true && lastSong.path != null
        ? Uri.file(lastSong.path!).toString()
        : _offlineService.getPlayableUrl(lastSong, _subsonicService);

    _isLoading = true;
    notifyListeners();

    try {
      await _audioPlayer.setUrl(playUrl);
      _position = lastPosition;
      await _audioPlayer.seek(lastPosition);
    } catch (e) {
      debugPrint('UPnP fallback: failed to reload local player: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
      _updateAndroidAuto();
    }
  }
}
