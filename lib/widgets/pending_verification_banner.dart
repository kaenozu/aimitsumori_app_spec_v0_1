/// ファイルパス: lib/widgets/pending_verification_banner.dart
/// 購入検証の進行状況を非破壊で通知するバナー。
/// 画面操作を妨げず、要確認（自動再試行終了）の場合はサポート案内を出す。
library;

import 'package:flutter/material.dart';

class PendingVerificationBanner extends StatelessWidget {
  const PendingVerificationBanner({
    super.key,
    required this.needsConfirmation,
    required this.pendingCount,
  });

  /// 自動再試行が終了し要確認となったレコードがあるかどうか。
  final bool needsConfirmation;

  /// 検証待ちレコード件数（要確認レコードを含む）。
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    if (pendingCount <= 0 && !needsConfirmation) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    final escalated = needsConfirmation;
    return Card(
      color: escalated ? colorScheme.errorContainer : null,
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(
          escalated ? Icons.error_outline : Icons.hourglass_top,
          color: escalated ? colorScheme.onErrorContainer : null,
        ),
        title: Text(
          escalated ? '要確認：購入の確認が未完了です' : '購入を確認中です',
          style: TextStyle(
            color: escalated ? colorScheme.onErrorContainer : null,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          escalated
              ? '購入の検証が完了していません。通信環境をご確認のうえ、復元でも解決しない場合はアプリのフィードバックからご連絡ください。'
              : '購入の検証に時間がかかっています。通信状態が回復すると自動的に再試行されます。',
          style: TextStyle(
            color: escalated ? colorScheme.onErrorContainer : null,
          ),
        ),
        dense: true,
      ),
    );
  }
}
