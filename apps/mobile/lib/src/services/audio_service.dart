import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'storage_service.dart';
import 'web_haptics_stub.dart'
    if (dart.library.js_interop) 'web_haptics_web.dart'
    as web_haptics;

/// Plays the original LudoMaster soundtrack, game sounds, and haptic feedback.
class AudioService {
  static bool soundEnabled = true;
  static bool hapticsEnabled = true;

  static AudioPlayer? _musicPlayer;
  static AudioPlayer? _effectsPlayer;
  static bool _musicRequested = false;
  static bool get _hasDeviceAudio =>
      kIsWeb || Platform.environment['FLUTTER_TEST'] != 'true';

  static Future<void> init() async {
    soundEnabled = await StorageService.getSoundEnabled();
    hapticsEnabled = await StorageService.getHapticsEnabled();
  }

  static Future<void> setSoundEnabled(bool enabled) async {
    soundEnabled = enabled;
    if (!enabled) {
      try {
        await _musicPlayer?.stop();
        await _effectsPlayer?.stop();
      } catch (_) {}
    } else if (_musicRequested) {
      await startGameMusic();
    }
  }

  static Future<void> startGameMusic() async {
    _musicRequested = true;
    if (!soundEnabled || !_hasDeviceAudio) return;

    try {
      final player = _musicPlayer ??= AudioPlayer();
      if (player.state == PlayerState.playing) return;
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(0.16);
      if (_musicRequested && soundEnabled) {
        await player.play(AssetSource('audio/game_music.wav'));
      }
    } catch (_) {
      // Audio is optional; a missing device audio plugin must not interrupt play.
    }
  }

  static Future<void> stopGameMusic() async {
    _musicRequested = false;
    try {
      await _musicPlayer?.stop();
    } catch (_) {}
  }

  static void playRollHaptic() {
    _haptic(HapticFeedback.lightImpact, webDurationMs: 55);
    _playEffect('audio/dice_roll.wav', volume: 0.75);
  }

  static void playMoveHaptic() {
    _haptic(HapticFeedback.selectionClick, webDurationMs: 25);
    _playEffect('audio/token_move.wav', volume: 0.8);
  }

  static void playCaptureHaptic() {
    _haptic(HapticFeedback.heavyImpact, webDurationMs: 90);
    _playEffect('audio/capture.wav', volume: 0.85);
  }

  static void playVictoryHaptic() {
    _haptic(HapticFeedback.vibrate, webDurationMs: 140);
    _playEffect('audio/victory.wav', volume: 0.8);
  }

  static void _haptic(
    Future<void> Function() feedback, {
    required int webDurationMs,
  }) {
    if (!hapticsEnabled) return;
    if (kIsWeb) {
      web_haptics.vibrate(webDurationMs);
    } else {
      unawaited(feedback());
    }
  }

  static void _playEffect(String asset, {required double volume}) {
    if (!soundEnabled || !_hasDeviceAudio) return;
    unawaited(() async {
      try {
        final player = _effectsPlayer ??= AudioPlayer();
        await player.stop();
        await player.setVolume(volume);
        await player.play(AssetSource(asset));
      } catch (_) {
        // Keep gameplay available even if the platform audio plugin fails.
      }
    }());
  }
}
