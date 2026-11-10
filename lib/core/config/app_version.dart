class AppVersion {
  AppVersion._();
  static const name = String.fromEnvironment(
    'FLUTTER_BUILD_NAME',
    defaultValue: 'desenvolvimento',
  );
  static const build = String.fromEnvironment(
    'FLUTTER_BUILD_NUMBER',
    defaultValue: 'local',
  );
  static String get label => name.startsWith('1.0.0-beta.') ? '1.0 Beta' : name;
}
