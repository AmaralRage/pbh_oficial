import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'platinum_chime.dart';

web.AudioContext? _active;
Timer? _cleanup;
web.AudioContext? _prepared;
Timer? _prepareCleanup;

void preparePlatinumSound() {
  if (_prepared != null) return;
  try {
    final context = web.AudioContext();
    _prepared = context;
    context.resume().toDart.catchError((Object _) => null);
    _prepareCleanup = Timer(const Duration(seconds: 30), () {
      if (identical(_prepared, context)) {
        _prepared = null;
        unawaited(context.close().toDart);
      }
    });
  } catch (_) {
    /* Permission failure must not prevent recording progress. */
  }
}

Future<void> playPlatinumSound(Future<bool> enabled) async {
  web.AudioContext? context;
  try {
    _cleanup?.cancel();
    final previous = _active;
    if (previous != null) unawaited(previous.close().toDart);
    // Resume during the actual click, before awaiting stored preferences.
    context = _prepared ?? web.AudioContext();
    _prepared = null;
    _prepareCleanup?.cancel();
    _active = context;
    final resumed = context.resume().toDart;
    final allowed = await enabled;
    await resumed;
    if (!identical(_active, context)) return;
    if (!allowed) {
      await context.close().toDart;
      _active = null;
      return;
    }
    final start = context.currentTime;
    for (var i = 0; i < platinumChimeFrequencies.length; i++) {
      final oscillator = context.createOscillator()..type = 'sine';
      final gain = context.createGain();
      final time = start + i * .115;
      oscillator.frequency.setValueAtTime(platinumChimeFrequencies[i], time);
      gain.gain.setValueAtTime(.0001, time);
      gain.gain.exponentialRampToValueAtTime(.095, time + .035);
      gain.gain.exponentialRampToValueAtTime(.0001, time + 1.25);
      oscillator.connect(gain);
      gain.connect(context.destination);
      oscillator.start(time);
      oscillator.stop(time + 1.3);
    }
    final playing = context;
    _cleanup = Timer(const Duration(milliseconds: 1800), () {
      if (identical(_active, playing)) {
        _active = null;
        unawaited(playing.close().toDart);
      }
    });
  } catch (_) {
    if (context != null && identical(_active, context)) {
      _active = null;
      try {
        await context.close().toDart;
      } catch (_) {}
    }
  }
}
