import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// PBH's interface stays in Brazilian Portuguese regardless of device language.
class AppLocalization {
  AppLocalization._();
  static const locale = Locale('pt', 'BR');
  static const supportedLocales = [locale];
  static const delegates = GlobalMaterialLocalizations.delegates;
}
