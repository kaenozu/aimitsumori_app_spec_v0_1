/// ファイルパス: lib/screens/settings_screen.dart
/// テーマ、アプリ情報、全データ削除を管理する設定画面
library;

import 'package:flutter/material.dart';

import '../repositories/project_repository.dart';
import '../services/haptic_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.repository,
    required this.darkModeEnabled,
    required this.onDarkModeChanged,
  });

  static const appVersion = '0.1.0+1';

  final ProjectRepository repository;
  final bool darkModeEnabled;
  final ValueChanged<bool> onDarkModeChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _darkModeEnabled;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _darkModeEnabled = widget.darkModeEnabled;
  }

  Future<void> _setDarkMode(bool enabled) async {
    await HapticService.lightImpact();
    if (!mounted) return;
    setState(() => _darkModeEnabled = enabled);
    widget.onDarkModeChanged(enabled);
  }

  Future<void> _requestDeleteAllData() async {
    await HapticService.lightImpact();
    if (!mounted) return;

    final continueDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('全データを削除しますか？'),
        content: const Text('保存済みの案件、見積、比較結果が削除対象です。設定内容と購入状態は削除されません。'),
        actions: [
          TextButton(
            onPressed: () async {
              await HapticService.lightImpact();
              if (dialogContext.mounted) Navigator.pop(dialogContext, false);
            },
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () async {
              await HapticService.lightImpact();
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            },
            child: const Text('削除を続ける'),
          ),
        ],
      ),
    );
    if (continueDelete != true || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(dialogContext).colorScheme.error,
        ),
        title: const Text('最終確認'),
        content: const Text('この操作は元に戻せません。本当にすべての案件データを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () async {
              await HapticService.lightImpact();
              if (dialogContext.mounted) Navigator.pop(dialogContext, false);
            },
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () async {
              await HapticService.lightImpact();
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            },
            child: const Text('完全に削除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await widget.repository.deleteAllData();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          SwitchListTile(
            key: const ValueKey('dark-mode-switch'),
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('ダークモード'),
            subtitle: const Text('画面全体を暗い配色に切り替えます。'),
            value: _darkModeEnabled,
            onChanged: _setDarkMode,
          ),
          const Divider(height: 1),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('バージョン'),
            subtitle: Text(SettingsScreen.appVersion),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.tonalIcon(
              key: const ValueKey('delete-all-data-button'),
              onPressed: _deleting ? null : _requestDeleteAllData,
              icon: _deleting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_forever_outlined),
              label: Text(_deleting ? '削除中…' : '全データを削除'),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '削除後もダークモード設定と広告削除の購入状態は維持されます。',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
