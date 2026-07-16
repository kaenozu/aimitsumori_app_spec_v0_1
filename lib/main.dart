/// ファイルパス: lib/main.dart
/// エントリポイント、広告・課金初期化、アプリテーマ
/// 関連ファイル: lib/screens/onboarding_screen.dart, lib/services/ad_service.dart
library;

import 'package:flutter/material.dart';

import 'screens/onboarding_screen.dart';
import 'services/ad_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AdService.instance.initialize();
  } catch (error) {
    debugPrint('Ad service initialization failed: $error');
  }
  runApp(const AimitsumoriApp());
}

class AimitsumoriApp extends StatelessWidget {
  const AimitsumoriApp({super.key});

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
      home: const FirstRunGate(),
    );
  }
}
