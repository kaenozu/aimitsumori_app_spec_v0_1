/// ファイルパス: lib/main.dart
/// エントリポイント、広告・課金初期化、アプリテーマ
/// 関連ファイル: lib/screens/onboarding_screen.dart, lib/services/ad_service.dart
library;

import 'package:flutter/material.dart';

import 'repositories/project_repository.dart';
import 'screens/onboarding_screen.dart';
import 'services/ad_service.dart';
import 'services/app_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AdService.instance.initialize();
  } catch (error) {
    debugPrint('Ad service initialization failed: $error');
  }
  runApp(const AimitsumoriApp());
}

class AimitsumoriApp extends StatefulWidget {
  const AimitsumoriApp({
    super.key,
    this.repository,
    this.adService,
    this.preferences,
  });

  final ProjectRepository? repository;
  final AdService? adService;
  final AppPreferences? preferences;

  @override
  State<AimitsumoriApp> createState() => _AimitsumoriAppState();
}

class _AimitsumoriAppState extends State<AimitsumoriApp> {
  bool _darkModeEnabled = false;

  AppPreferences get _preferences =>
      widget.preferences ?? AppPreferences.instance;

  @override
  void initState() {
    super.initState();
    _loadDarkMode();
  }

  Future<void> _loadDarkMode() async {
    try {
      final enabled = await _preferences.isDarkModeEnabled();
      if (mounted) setState(() => _darkModeEnabled = enabled);
    } catch (error) {
      debugPrint('Dark mode preference load failed: $error');
    }
  }

  Future<void> _setDarkMode(bool enabled) async {
    final previous = _darkModeEnabled;
    setState(() => _darkModeEnabled = enabled);
    try {
      await _preferences.setDarkModeEnabled(enabled);
    } catch (error) {
      debugPrint('Dark mode preference save failed: $error');
      if (mounted) setState(() => _darkModeEnabled = previous);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '相見積もり比較',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: _darkModeEnabled ? ThemeMode.dark : ThemeMode.light,
      home: FirstRunGate(
        repository: widget.repository,
        adService: widget.adService,
        darkModeEnabled: _darkModeEnabled,
        onDarkModeChanged: _setDarkMode,
      ),
    );
  }
}
