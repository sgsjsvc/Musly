import 'dart:async';
import 'package:flutter/foundation.dart';

/// Manages the sleep timer, including fade-out functionality.
///
/// Extracted from [PlayerProvider] to reduce its size and keep the timer
/// logic self-contained.
class SleepTimerController extends ChangeNotifier {
  Timer? _sleepTimer;
  DateTime? _sleepTimerEnd;
  bool _endCurrentSong = false;
  bool _fadeOut = false;
  int _fadeDurationSeconds = 30;
  Timer? _fadeStartTimer;
  Timer? _fadePeriodicTimer;

  /// Callback invoked when the sleep timer expires.
  /// The owner should call [pause] / [stop] in response.
  VoidCallback? onTimerExpired;

  /// Callback to set the audio player volume (0.0–1.0) during fade-out.
  ValueChanged<double>? onSetVolume;

  /// The user-configured volume to restore after a fade cycle.
  double userVolume = 1.0;

  bool get isActive => _sleepTimer != null;
  bool get endCurrentSong => _endCurrentSong;
  bool get fadeOutEnabled => _fadeOut;
  int get fadeDurationSeconds => _fadeDurationSeconds;

  Duration? get remaining {
    if (_sleepTimerEnd == null) return null;
    final r = _sleepTimerEnd!.difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }

  void set({
    required Duration duration,
    bool endCurrentSong = false,
    bool fadeOut = false,
    int fadeDurationSeconds = 30,
  }) {
    cancel();
    _endCurrentSong = endCurrentSong;
    _fadeOut = fadeOut;
    _fadeDurationSeconds = fadeDurationSeconds;

    if (duration > Duration.zero) {
      _sleepTimerEnd = DateTime.now().add(duration);

      if (fadeOut) {
        final fadeStart = duration - Duration(seconds: fadeDurationSeconds);
        if (fadeStart > Duration.zero) {
          _fadeStartTimer =
              Timer(fadeStart, () => _startFadeOut(fadeDurationSeconds));
        } else {
          _startFadeOut(fadeDurationSeconds);
        }
      }

      _sleepTimer = Timer(duration, () {
        if (endCurrentSong) {
          _endCurrentSong = true;
          _sleepTimer = null;
          _sleepTimerEnd = null;
          notifyListeners();
        } else {
          _doStop();
        }
      });
    }
    notifyListeners();
  }

  /// Called by the owner when a song naturally ends and
  /// [endCurrentSong] is true.
  void handleSongComplete() {
    if (_endCurrentSong) {
      _doStop();
    }
  }

  void cancel() {
    _sleepTimer?.cancel();
    _fadeStartTimer?.cancel();
    _fadePeriodicTimer?.cancel();
    _fadePeriodicTimer = null;
    _sleepTimer = null;
    _sleepTimerEnd = null;
    _endCurrentSong = false;
    _fadeOut = false;
    _fadeDurationSeconds = 30;
  }

  void _startFadeOut([int fadeDurationSeconds = 30]) {
    _fadePeriodicTimer?.cancel();
    final steps = fadeDurationSeconds.clamp(5, 300);
    const stepDuration = Duration(seconds: 1);
    final originalVolume = userVolume;
    int step = 0;
    _fadePeriodicTimer = Timer.periodic(stepDuration, (t) {
      step++;
      final newVolume = originalVolume * (1.0 - step / steps);
      onSetVolume?.call(newVolume.clamp(0.0, 1.0));
      if (step >= steps) {
        t.cancel();
        _fadePeriodicTimer = null;
      }
    });
  }

  void _doStop() {
    _fadePeriodicTimer?.cancel();
    _fadePeriodicTimer = null;
    onSetVolume?.call(userVolume);
    onTimerExpired?.call();
    _sleepTimer = null;
    _sleepTimerEnd = null;
    _fadeOut = false;
    _fadeDurationSeconds = 30;
    _endCurrentSong = false;
    notifyListeners();
  }

  @override
  void dispose() {
    cancel();
    super.dispose();
  }
}
