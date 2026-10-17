import 'package:flutter/foundation.dart';

class SpotifyPlaybackController extends ChangeNotifier {
  SpotifyPlaybackController._();

  static final SpotifyPlaybackController instance = SpotifyPlaybackController._();

  bool _opened = false;
  bool _expanded = false;

  bool get opened => _opened;
  bool get expanded => _expanded;

  void open() {
    _opened = true;
    _expanded = true;
    notifyListeners();
  }

  void minimize() {
    if (!_opened || !_expanded) return;
    _expanded = false;
    notifyListeners();
  }

  void expand() {
    if (!_opened || _expanded) return;
    _expanded = true;
    notifyListeners();
  }
}
