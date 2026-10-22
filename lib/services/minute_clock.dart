import 'dart:async';
import 'package:flutter/foundation.dart';

/// A single clock shared by visible posts; it stops when nobody is listening.
class MinuteClock extends ChangeNotifier {
  static final shared = MinuteClock();
  Timer? _timer;
  DateTime get now => DateTime.now();
  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _timer ??= Timer.periodic(
      const Duration(minutes: 1),
      (_) => notifyListeners(),
    );
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
