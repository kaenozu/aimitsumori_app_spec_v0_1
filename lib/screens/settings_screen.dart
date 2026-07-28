/// ファイルパス: lib/screens/settings_screen.dart
/// テーマ、アプリ情報、全データ削除を管理する設定画面
library;

import '../utils/app_logger.dart';

import 'package:flutter/material.dart';

import '../repositories/project_repository.dart';
import '../services/haptic_service.dart';
import '../services/ocr_review_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.repository,
    required this.darkModeEnabled,
    required this.onDarkModeChanged,
    this.reviewStore,
  });

  static const appVersion = '0.1.0+1';

  final ProjectRepository repository;
  final bool darkModeEnabled;
  final ValueChanged<bool> onDarkModeChanged;
  final OcrReviewStore? reviewStore;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _darkModeEnabled;
  bool _deleting = false;

  OcrReviewStore get _reviewStore => widget.reviewStore ?? OcrReviewStore();

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
      await _reviewStore.clearAll();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      AppLogger.debug('Delete all data failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('データを削除できませんでした。もう一度お試しください。')),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _showPrivacySummary() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('データとプライバシー'),
        content: const SingleChildScrollView(
          child: Text(
            '案件、見積、OCR結果、確認状態は端末内に保存されます。\n\n'
            '見積書のOCR処理は端末上で行われ、アプリから外部サービスへ見積内容を送信しません。\n\n'
            '比較結果の共有を実行した場合だけ、選択した内容が端末の共有先へ渡ります。\n\n'
            '広告表示と広告削除購入では、Google Playおよび広告SDKのプライバシーポリシーが適用されます。\n\n'
            '保存した案件・見積・比較結果は「全データを削除」から削除できます。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
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
          ListTile(
            key: const ValueKey('privacy-summary-button'),
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('データとプライバシー'),
            subtitle: const Text('保存・OCR・共有・広告の取り扱い'),
            onTap: _showPrivacySummary,
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
