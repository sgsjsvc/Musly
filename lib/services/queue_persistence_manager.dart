import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';

/// Encapsulates all queue persistence logic (save/restore/clear) that was
/// previously inlined in [PlayerProvider].
///
/// Uses [SharedPreferences] with a 200 ms debounce to avoid excessive writes.
class QueuePersistenceManager {
  SharedPreferences? _prefs;
  Timer? _debounceTimer;

  static const String _keyQueue = 'persistent_queue';
  static const String _keyQueueIndex = 'persistent_queue_index';
  static const String _keyQueueSongId = 'persistent_queue_song_id';
  static const String _keyQueuePosition = 'persistent_queue_position_ms';

  /// Schedule a debounced save of the current queue state.
  void save({
    required List<Song> queue,
    required int currentIndex,
    required String? currentSongId,
    required Duration position,
  }) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      saveImmediate(
        queue: queue,
        currentIndex: currentIndex,
        currentSongId: currentSongId,
        position: position,
      );
    });
  }

  /// Save queue state immediately (no debounce). Use when the app is going
  /// to background or shutting down.
  Future<void> saveImmediate({
    required List<Song> queue,
    required int currentIndex,
    required String? currentSongId,
    required Duration position,
  }) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      if (_prefs == null) return;
      final queueJson = queue.map((s) => s.toJson()).toList();
      await _prefs!.setString(_keyQueue, jsonEncode(queueJson));
      await _prefs!.setInt(_keyQueueIndex, currentIndex);
      await _prefs!.setString(_keyQueueSongId, currentSongId ?? '');
      await _prefs!.setInt(_keyQueuePosition, position.inMilliseconds);
      debugPrint(
          'Queue state saved: index $currentIndex, position $position');
    } catch (e) {
      debugPrint('Error saving queue state: $e');
    }
  }

  /// Result of a queue restore operation.
  Future<RestoredQueueState?> restore() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      if (_prefs == null) return null;

      final queueRaw = _prefs!.getString(_keyQueue);
      if (queueRaw == null || queueRaw.isEmpty) return null;

      final queueJson = jsonDecode(queueRaw) as List<dynamic>;
      if (queueJson.isEmpty) return null;

      final restoredSongs = queueJson
          .map((j) => Song.fromJson(j as Map<String, dynamic>))
          .where((s) {
        // Validate local files still exist.
        if (s.isLocal && s.path != null) {
          return File(s.path!).existsSync();
        }
        return true;
      }).toList();

      if (restoredSongs.isEmpty) return null;

      final savedIndex = _prefs!.getInt(_keyQueueIndex) ?? 0;
      final savedSongId = _prefs!.getString(_keyQueueSongId);
      final savedPositionMs = _prefs!.getInt(_keyQueuePosition) ?? 0;

      var targetIndex = savedIndex.clamp(0, restoredSongs.length - 1);
      if (savedSongId != null && savedSongId.isNotEmpty) {
        final idIndex = restoredSongs.indexWhere((s) => s.id == savedSongId);
        if (idIndex != -1) targetIndex = idIndex;
      }

      debugPrint(
          'Restored persistent queue: ${restoredSongs.length} songs, index $targetIndex, position ${Duration(milliseconds: savedPositionMs)}');

      return RestoredQueueState(
        songs: restoredSongs,
        currentIndex: targetIndex,
        position: Duration(milliseconds: savedPositionMs),
      );
    } catch (e) {
      debugPrint('Error restoring queue state: $e');
      return null;
    }
  }

  /// Clear all persisted queue data.
  void clear() {
    _debounceTimer?.cancel();
    try {
      SharedPreferences.getInstance().then((p) {
        p.remove(_keyQueue);
        p.remove(_keyQueueIndex);
        p.remove(_keyQueueSongId);
        p.remove(_keyQueuePosition);
      });
    } catch (_) {}
  }

  /// Cancel the debounce timer. Call from the owner's [dispose].
  void dispose() {
    _debounceTimer?.cancel();
  }
}

/// Immutable snapshot of restored queue state.
class RestoredQueueState {
  final List<Song> songs;
  final int currentIndex;
  final Duration position;

  const RestoredQueueState({
    required this.songs,
    required this.currentIndex,
    required this.position,
  });
}
