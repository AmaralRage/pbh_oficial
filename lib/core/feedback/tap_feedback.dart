import 'package:flutter/services.dart';

/// Retorno tátil discreto para ações de toque.
/// Em plataformas sem vibração, a chamada é ignorada pelo Flutter.
void lightTapFeedback() => HapticFeedback.selectionClick();
