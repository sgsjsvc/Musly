import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'storage_service.dart';
import 'queue_persistence_manager.dart';

enum RepeatMode { off, all, one }

class QueueManager extends ChangeNotifier {
  final StorageService _storageService;
  final QueuePersistenceManager _persistenceManager;

  List<Song> _queue = [];
  int _currentIndex = -1;
  bool _shuffleEnabled = false;
  final List<String> _shuffleHistory = [];
  RepeatMode _repeatMode = RepeatMode.off;

  QueueManager(this._storageService, this._persistenceManager);

  List<Song> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get shuffleEnabled => _shuffleEnabled;
  RepeatMode get repeatMode => _repeatMode;
  List<String> get shuffleHistory => _shuffleHistory;

  Song? get currentSong {
    if (_currentIndex >= 0 && _currentIndex < _queue.length) {
      return _queue[_currentIndex];
    }
    return null;
  }

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

  Future<void> initialize() async {
    _shuffleEnabled = await _storageService.getShuffleMode();
    final repeatIdx = await _storageService.getRepeatMode();
    _repeatMode = RepeatMode.values[repeatIdx.clamp(0, RepeatMode.values.length - 1)];

    final restored = await _persistenceManager.restore();
    if (restored != null) {
      _queue = restored.songs;
      _currentIndex = restored.currentIndex;
    }
    notifyListeners();
  }

  void saveState(Duration position) {
    _persistenceManager.save(
      queue: _queue,
      currentIndex: _currentIndex,
      currentSongId: currentSong?.id,
      position: position,
    );
  }

  void saveStateImmediate(Duration position) {
    _persistenceManager.saveImmediate(
      queue: _queue,
      currentIndex: _currentIndex,
      currentSongId: currentSong?.id,
      position: position,
    );
  }

  void clearQueue() {
    _queue.clear();
    _currentIndex = -1;
    _persistenceManager.clear();
    notifyListeners();
  }

  void setQueue(List<Song> newQueue, {int initialIndex = 0}) {
    _queue = List.from(newQueue);
    _currentIndex = initialIndex;
    notifyListeners();
  }

  void insertNext(Song song) {
    final insertIndex = _currentIndex + 1;
    if (insertIndex < _queue.length) {
      _queue.insert(insertIndex, song);
    } else {
      _queue.add(song);
    }
    notifyListeners();
  }

  void add(Song song) {
    _queue.add(song);
    notifyListeners();
  }

  void addAll(Iterable<Song> songs) {
    _queue.addAll(songs);
    notifyListeners();
  }

  void removeAt(int index) {
    if (index >= 0 && index < _queue.length) {
      _queue.removeAt(index);
      if (index < _currentIndex) {
        _currentIndex--;
      } else if (index == _currentIndex && _queue.isNotEmpty) {
        if (_currentIndex >= _queue.length) {
          _currentIndex = _queue.length - 1;
        }
      } else if (_queue.isEmpty) {
        _currentIndex = -1;
      }
      notifyListeners();
    }
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final song = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, song);

    if (oldIndex == _currentIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex -= 1;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex += 1;
    }
    notifyListeners();
  }

  void toggleShuffle() {
    _shuffleEnabled = !_shuffleEnabled;
    _shuffleHistory.clear();
    if (_shuffleEnabled && _queue.length > 1 && currentSong != null) {
      final current = currentSong!;
      _queue.shuffle();
      _queue.remove(current);
      _queue.insert(0, current);
      _currentIndex = 0;
    }
    _storageService.saveShuffleMode(_shuffleEnabled);
    notifyListeners();
  }

  void toggleRepeat() {
    switch (_repeatMode) {
      case RepeatMode.off:
        _repeatMode = RepeatMode.all;
        break;
      case RepeatMode.all:
        _repeatMode = RepeatMode.one;
        break;
      case RepeatMode.one:
        _repeatMode = RepeatMode.off;
        break;
    }
    _storageService.saveRepeatMode(_repeatMode.index);
    notifyListeners();
  }

  void setCurrentIndex(int index) {
    if (index >= 0 && index < _queue.length) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  int getNextIndex() {
    if (_shuffleEnabled) {
      final available = List.generate(_queue.length, (i) => i)..remove(_currentIndex);
      if (available.isEmpty) return _currentIndex;
      available.shuffle();
      _shuffleHistory.add(currentSong!.id);
      return available.first;
    }
    if (_currentIndex < _queue.length - 1) {
      return _currentIndex + 1;
    }
    if (_repeatMode == RepeatMode.all && _queue.isNotEmpty) {
      return 0;
    }
    return -1;
  }

  int getPreviousIndex() {
    if (_shuffleEnabled && _shuffleHistory.isNotEmpty) {
      final prevId = _shuffleHistory.removeLast();
      final prev = _queue.indexWhere((s) => s.id == prevId);
      if (prev != -1) return prev;
    }
    if (_currentIndex > 0) {
      return _currentIndex - 1;
    }
    if (_repeatMode == RepeatMode.all && _queue.isNotEmpty) {
      return _queue.length - 1;
    }
    return -1;
  }
}
