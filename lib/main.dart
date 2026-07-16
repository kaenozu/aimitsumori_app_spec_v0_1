/// ファイルパス: lib/main.dart
/// エントリポイント & ナビゲーション
/// 関連ファイル: lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
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
      home: const HomeScreen(),
    );
  }
}
