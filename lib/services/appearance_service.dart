import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme/pbh_palette.dart';
import 'auth_service.dart';

class AppearanceService extends ChangeNotifier {
  AppearanceService({SharedPreferencesAsync? storage})
    : storage = storage ?? SharedPreferencesAsync();
  static final instance = AppearanceService();
  final SharedPreferencesAsync storage;
  SupabaseClient? _client;
  StreamSubscription<AuthState>? _subscription;
  int _generation = 0;
  String? _account;
  PbhPalette _palette = PbhPalette.catalog.first;
  PbhPalette get selectedPalette => _palette;
  bool _fullApp = true;
  bool get fullApp => _fullApp;
  PbhPalette get palette => _fullApp ? _palette : PbhPalette.catalog.first;
  bool _reducedEffects = false;
  bool get reducedEffects => _reducedEffects;
  bool _highContrast = false;
  bool get highContrast => _highContrast;
  Future<void> setHighContrast(bool value) async {
    await storage.setBool('pbh.appearance.high_contrast', value);
    _highContrast = value;
    notifyListeners();
  }

  Future<void> setReducedEffects(bool value) async {
    await storage.setBool('pbh.appearance.reduced_effects', value);
    _reducedEffects = value;
    notifyListeners();
  }

  bool get founder => AuthService.isProjectLeader(_client?.auth.currentUser);
  Future<void> bind(SupabaseClient? client) async {
    await _subscription?.cancel();
    _client = client;
    _subscription = client?.auth.onAuthStateChange.listen((_) {
      unawaited(refresh());
    });
    await refresh();
  }

  Future<void> refresh() async {
    final version = ++_generation;
    final user = _client?.auth.currentUser;
    final account = user?.id ?? 'guest';
    if (_account != account) {
      _account = account;
      _palette = PbhPalette.catalog.first;
      _fullApp = true;
      notifyListeners();
    }
    String? cached;
    bool? cachedScope;
    try {
      cached = await storage.getString('pbh.appearance.$account');
      cachedScope = await storage.getBool('pbh.appearance.full_app.$account');
      _reducedEffects =
          await storage.getBool('pbh.appearance.reduced_effects') ?? false;
      _highContrast =
          await storage.getBool('pbh.appearance.high_contrast') ?? false;
    } catch (_) {}
    if (version != _generation) return;
    final remote = user?.userMetadata?['app_theme'];
    final remoteScope = user?.userMetadata?['theme_full_app'];
    _fullApp = remoteScope is bool ? remoteScope : cachedScope ?? true;
    _palette = PbhPalette.resolve(
      remote is String ? remote : cached,
      founder: AuthService.isProjectLeader(user),
    );
    notifyListeners();
  }

  Future<void> apply(String id, {bool fullApp = true}) async {
    final user = _client?.auth.currentUser;
    final account = user?.id ?? 'guest';
    final selected = PbhPalette.resolve(
      id,
      founder: AuthService.isProjectLeader(user),
    );
    if (selected.id != id)
      throw StateError('Este tema não está disponível para sua conta.');
    if (user != null) {
      final currentStyle = user.userMetadata?['profile_style'];
      await _client!.auth.updateUser(
        UserAttributes(
          data: {
            'app_theme': id,
            'theme_full_app': fullApp,
            'profile_style': {
              if (currentStyle is Map)
                ...Map<String, dynamic>.from(currentStyle),
              'profile_theme': fullApp ? 'app' : id,
            },
          },
        ),
      );
    }
    if ((_client?.auth.currentUser?.id ?? 'guest') != account)
      throw StateError('A conta mudou. Reabra a aparência.');
    await storage.setString('pbh.appearance.$account', id);
    await storage.setBool('pbh.appearance.full_app.$account', fullApp);
    if ((_client?.auth.currentUser?.id ?? 'guest') != account) {
      throw StateError('A conta mudou. Reabra a aparência.');
    }
    ++_generation;
    _palette = selected;
    _fullApp = fullApp;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
