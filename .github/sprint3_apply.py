from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    content = file_path.read_text(encoding="utf-8")
    count = content.count(old)
    if count != 1:
        raise RuntimeError(f"{path}: expected one match, found {count}\n--- old ---\n{old}")
    file_path.write_text(content.replace(old, new, 1), encoding="utf-8")


def write(path: str, content: str) -> None:
    file_path = Path(path)
    file_path.parent.mkdir(parents=True, exist_ok=True)
    file_path.write_text(content, encoding="utf-8")


# ---------------------------------------------------------------------------
# Shared normalization utilities and tests
# ---------------------------------------------------------------------------
replace_once(
    "lib/services/value_normalizer.dart",
    """/// 数値・単位・CSVセルを安全に正規化する共通ユーティリティ。
library;
""",
    """/// ファイルパス: lib/services/value_normalizer.dart
/// 目的: 数値とCSVセルを安全に正規化する共通ユーティリティ。
/// 存在理由: OCR・手入力・共有処理の入力差を一箇所で吸収するため。
/// 関連ファイル: text_normalizer.dart, unit_normalizer.dart, ocr_service.dart
library;

export 'unit_normalizer.dart';
""",
)

replace_once(
    "lib/services/value_normalizer.dart",
    """class UnitNormalizer {
  const UnitNormalizer._();

  static String? normalize(String? raw) {
    final value = raw?.trim().toLowerCase();
    if (value == null || value.isEmpty) return null;
    final compact = value.replaceAll(RegExp(r'\\s+'), '');
    return switch (compact) {
      'm2' || 'm^2' || 'm²' || '㎡' => '㎡',
      'm3' || 'm^3' || 'm³' || '㎥' => '㎥',
      'メートル' || 'ｍ' || 'm' => 'm',
      'ミリ' || 'ミリメートル' || 'ｍｍ' || 'mm' => 'mm',
      'センチ' || 'センチメートル' || 'ｃｍ' || 'cm' => 'cm',
      'ヶ所' || 'ケ所' || 'か所' || '箇所' => '箇所',
      '一式' || '式' => '式',
      _ => compact,
    };
  }

  static _ConvertedQuantity? _convert(double quantity, String? rawUnit) {
    final unit = normalize(rawUnit);
    if (unit == null) return null;
    return switch (unit) {
      'mm' => _ConvertedQuantity('length', quantity / 1000),
      'cm' => _ConvertedQuantity('length', quantity / 100),
      'm' => _ConvertedQuantity('length', quantity),
      '㎡' => _ConvertedQuantity('area', quantity),
      '㎥' => _ConvertedQuantity('volume', quantity),
      _ => _ConvertedQuantity('discrete:$unit', quantity),
    };
  }

  static bool equivalent(String? left, String? right) {
    final normalizedLeft = normalize(left);
    final normalizedRight = normalize(right);
    if (normalizedLeft == null || normalizedRight == null) return false;
    final leftConverted = _convert(1, normalizedLeft);
    final rightConverted = _convert(1, normalizedRight);
    return leftConverted?.dimension == rightConverted?.dimension;
  }

  static bool quantitiesEquivalent({
    required double expected,
    required String expectedUnit,
    required double actual,
    required String actualUnit,
  }) {
    final convertedExpected = _convert(expected, expectedUnit);
    final convertedActual = _convert(actual, actualUnit);
    if (convertedExpected == null || convertedActual == null) return false;
    if (convertedExpected.dimension != convertedActual.dimension) return false;
    final tolerance = (convertedExpected.value.abs() * 0.001).clamp(
      0.01,
      1000.0,
    );
    return (convertedExpected.value - convertedActual.value).abs() <= tolerance;
  }
}

""",
    "",
)

replace_once(
    "lib/services/value_normalizer.dart",
    """class _ConvertedQuantity {
  const _ConvertedQuantity(this.dimension, this.value);

  final String dimension;
  final double value;
}
""",
    "",
)

write(
    "lib/services/text_normalizer.dart",
    """/// ファイルパス: lib/services/text_normalizer.dart
/// 目的: OCR・手入力テキストの表記ゆれを安全に正規化する。
/// 存在理由: 全角英数、長音、括弧類の変換規則を共有するため。
/// 関連ファイル: value_normalizer.dart, unit_normalizer.dart, ocr_service.dart
library;

class TextNormalizer {
  const TextNormalizer._();

  static String? normalize(String? input) {
    if (input == null) return null;

    var normalized = String.fromCharCodes(
      input.runes.map((rune) {
        if (rune == 0x3000) return 0x20;
        if (rune >= 0xff01 && rune <= 0xff5e) return rune - 0xfee0;
        return rune;
      }),
    );

    normalized = normalized
        .replaceAll(RegExp(r'[ー―−‐‑–—]'), '-')
        .replaceAll('【', '[')
        .replaceAll('】', ']')
        .replaceAll('「', '[')
        .replaceAll('」', ']')
        .replaceAll('『', '[')
        .replaceAll('』', ']')
        .replaceAll('〈', '<')
        .replaceAll('〉', '>')
        .replaceAll('《', '<')
        .replaceAll('》', '>')
        .trim();

    return normalized.isEmpty ? null : normalized;
  }
}
""",
)

write(
    "lib/services/unit_normalizer.dart",
    """/// ファイルパス: lib/services/unit_normalizer.dart
/// 目的: 比較用単位と外部出力用単位を正規化・換算する。
/// 存在理由: 単位表記の揺れと長さ換算を一貫して扱うため。
/// 関連ファイル: value_normalizer.dart, text_normalizer.dart, requirements_engine.dart
library;

import 'text_normalizer.dart';

class UnitNormalizer {
  const UnitNormalizer._();

  static String? convert(String? raw) {
    final normalized = TextNormalizer.normalize(raw)?.toLowerCase();
    if (normalized == null) return null;
    final compact = normalized.replaceAll(RegExp(r'\\s+'), '');
    return switch (compact) {
      '個' || '個入り' || 'pc' || 'pcs' || 'piece' || 'pieces' => 'pieces',
      'ml' || 'ミリリットル' => 'ml',
      'l' || 'ℓ' || 'リットル' => 'l',
      'g' || 'グラム' => 'g',
      'kg' || 'キログラム' => 'kg',
      'mm' || 'ミリ' || 'ミリメートル' => 'mm',
      'cm' || 'センチ' || 'センチメートル' => 'cm',
      'm' || 'メートル' => 'm',
      'm2' || 'm^2' || 'm²' || '㎡' => 'm2',
      'm3' || 'm^3' || 'm³' || '㎥' => 'm3',
      _ => compact,
    };
  }

  static String? normalize(String? raw) {
    final value = raw?.trim().toLowerCase();
    if (value == null || value.isEmpty) return null;
    final compact = value.replaceAll(RegExp(r'\\s+'), '');
    return switch (compact) {
      'm2' || 'm^2' || 'm²' || '㎡' => '㎡',
      'm3' || 'm^3' || 'm³' || '㎥' => '㎥',
      'メートル' || 'ｍ' || 'm' => 'm',
      'ミリ' || 'ミリメートル' || 'ｍｍ' || 'mm' => 'mm',
      'センチ' || 'センチメートル' || 'ｃｍ' || 'cm' => 'cm',
      'ヶ所' || 'ケ所' || 'か所' || '箇所' => '箇所',
      '一式' || '式' => '式',
      _ => compact,
    };
  }

  static _ConvertedQuantity? _convert(double quantity, String? rawUnit) {
    final unit = normalize(rawUnit);
    if (unit == null) return null;
    return switch (unit) {
      'mm' => _ConvertedQuantity('length', quantity / 1000),
      'cm' => _ConvertedQuantity('length', quantity / 100),
      'm' => _ConvertedQuantity('length', quantity),
      '㎡' => _ConvertedQuantity('area', quantity),
      '㎥' => _ConvertedQuantity('volume', quantity),
      _ => _ConvertedQuantity('discrete:$unit', quantity),
    };
  }

  static bool equivalent(String? left, String? right) {
    final normalizedLeft = normalize(left);
    final normalizedRight = normalize(right);
    if (normalizedLeft == null || normalizedRight == null) return false;
    final leftConverted = _convert(1, normalizedLeft);
    final rightConverted = _convert(1, normalizedRight);
    return leftConverted?.dimension == rightConverted?.dimension;
  }

  static bool quantitiesEquivalent({
    required double expected,
    required String expectedUnit,
    required double actual,
    required String actualUnit,
  }) {
    final convertedExpected = _convert(expected, expectedUnit);
    final convertedActual = _convert(actual, actualUnit);
    if (convertedExpected == null || convertedActual == null) return false;
    if (convertedExpected.dimension != convertedActual.dimension) return false;
    final tolerance = (convertedExpected.value.abs() * 0.001).clamp(
      0.01,
      1000.0,
    );
    return (convertedExpected.value - convertedActual.value).abs() <= tolerance;
  }
}

class _ConvertedQuantity {
  const _ConvertedQuantity(this.dimension, this.value);

  final String dimension;
  final double value;
}
""",
)

write(
    "test/text_normalizer_test.dart",
    """/// ファイルパス: test/text_normalizer_test.dart
/// 目的: TextNormalizerの全変換規則と境界値を検証する。
/// 存在理由: OCR・手入力の表記揺れが比較結果へ混入する回帰を防ぐため。
/// 関連ファイル: lib/services/text_normalizer.dart
library;

import 'package:aimitsumori_app/services/text_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TextNormalizer.normalize', () {
    test('nullと空文字はnullになる', () {
      expect(TextNormalizer.normalize(null), isNull);
      expect(TextNormalizer.normalize(''), isNull);
      expect(TextNormalizer.normalize('　 －  '.replaceAll('－', '')), isNull);
    });

    test('全角英数と記号を半角へ変換する', () {
      expect(
        TextNormalizer.normalize('ＡＢＣ１２３ａｂｃ！'),
        'ABC123abc!',
      );
    });

    test('長音と各種ダッシュをハイフンへ統一する', () {
      expect(
        TextNormalizer.normalize('コンクリートー外構―工事−追加'),
        'コンクリート-外構-工事-追加',
      );
    });

    test('括弧類をASCIIへ変換する', () {
      expect(
        TextNormalizer.normalize('（A）［B］｛C｝【D】「E」『F』〈G〉'),
        '(A)[B]{C}[D][E][F]<G>',
      );
    });

    test('特殊文字と絵文字は保持する', () {
      expect(TextNormalizer.normalize('見積@#%😊'), '見積@#%😊');
    });

    test('複合入力を一度に正規化する', () {
      expect(
        TextNormalizer.normalize('　Ａ社（１２３）ー😊　'),
        'A社(123)-😊',
      );
    });
  });
}
""",
)

write(
    "test/unit_normalizer_test.dart",
    """/// ファイルパス: test/unit_normalizer_test.dart
/// 目的: UnitNormalizer.convertの全変換ケースと境界値を検証する。
/// 存在理由: 容量・個数・長さの表記揺れによる比較誤差を防ぐため。
/// 関連ファイル: lib/services/unit_normalizer.dart
library;

import 'package:aimitsumori_app/services/unit_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UnitNormalizer.convert', () {
    test('nullと空文字はnullになる', () {
      expect(UnitNormalizer.convert(null), isNull);
      expect(UnitNormalizer.convert(''), isNull);
      expect(UnitNormalizer.convert('　 '), isNull);
    });

    test('個数単位をpiecesへ変換する', () {
      for (final input in ['個', '個入り', 'pc', 'pcs', 'piece', 'pieces']) {
        expect(UnitNormalizer.convert(input), 'pieces', reason: input);
      }
    });

    test('ミリリットル表記をmlへ変換する', () {
      for (final input in ['ml', 'ｍｌ', 'ML', 'ミリリットル']) {
        expect(UnitNormalizer.convert(input), 'ml', reason: input);
      }
    });

    test('リットル表記をlへ変換する', () {
      for (final input in ['l', 'L', 'ｌ', 'ℓ', 'リットル']) {
        expect(UnitNormalizer.convert(input), 'l', reason: input);
      }
    });

    test('重量単位を変換する', () {
      expect(UnitNormalizer.convert('グラム'), 'g');
      expect(UnitNormalizer.convert('ｋｇ'), 'kg');
      expect(UnitNormalizer.convert('キログラム'), 'kg');
    });

    test('長さ・面積・体積単位を変換する', () {
      expect(UnitNormalizer.convert('ミリメートル'), 'mm');
      expect(UnitNormalizer.convert('cm'), 'cm');
      expect(UnitNormalizer.convert('メートル'), 'm');
      expect(UnitNormalizer.convert('㎡'), 'm2');
      expect(UnitNormalizer.convert('m³'), 'm3');
    });

    test('未知単位と絵文字を破壊しない', () {
      expect(UnitNormalizer.convert(' 箱 😊 '), '箱😊');
    });
  });
}
""",
)

# ---------------------------------------------------------------------------
# Comparison screen semantics and concise labels
# ---------------------------------------------------------------------------
replace_once(
    "lib/screens/comparison_screen.dart",
    """/// ファイルパス: lib/screens/comparison_screen.dart
/// 比較画面 - 更新、PDF・画像・CSV・テキスト共有、カテゴリ比較、質問テンプレート、広告
""",
    """/// ファイルパス: lib/screens/comparison_screen.dart
/// 目的: 見積の差、不明点、確認質問をアクセシブルに表示・共有する。
/// 存在理由: 業者ごとの条件差を順位付けせず確認できる中核画面のため。
/// 関連ファイル: comparison_engine.dart, quote_input_screen.dart, comparison_export_service.dart
""",
)

replace_once(
    "lib/screens/comparison_screen.dart",
    """              tooltip: '比較結果を共有',
              onPressed: _exporting
                  ? null
                  : () => _showShareOptions(shareContext),
              icon: _exporting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share_outlined),
""",
    """              tooltip: '共有',
              onPressed: _exporting
                  ? null
                  : () => _showShareOptions(shareContext),
              icon: _exporting
                  ? const Semantics(
                      label: '共有中',
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.share_outlined, semanticLabel: '共有'),
""",
)

replace_once(
    "lib/screens/comparison_screen.dart",
    """              tooltip: '見積を追加',
              onPressed: _addQuote,
              icon: const Icon(Icons.document_scanner_outlined),
""",
    """              tooltip: '追加',
              onPressed: _addQuote,
              icon: const Icon(
                Icons.document_scanner_outlined,
                semanticLabel: '見積を追加',
              ),
""",
)

replace_once(
    "lib/screens/comparison_screen.dart",
    """                      Text(
                        _report.projectName,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
""",
    """                      Semantics(
                        header: true,
                        child: Text(
                          _report.projectName,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
""",
)

replace_once(
    "lib/screens/comparison_screen.dart",
    """                        OutlinedButton.icon(
                          onPressed: _addQuote,
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: const Text('PDF・写真から見積を追加'),
                        ),
""",
    """                        Semantics(
                          button: true,
                          label: 'PDFまたは写真から見積を追加',
                          child: ExcludeSemantics(
                            child: OutlinedButton.icon(
                              onPressed: _addQuote,
                              icon: const Icon(Icons.add_a_photo_outlined),
                              label: const Text('追加'),
                            ),
                          ),
                        ),
""",
)

replace_once(
    "lib/screens/comparison_screen.dart",
    """            const Text('3行サマリー', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (var index = 0; index < lines.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${index + 1}. ${lines[index]}'),
              ),
""",
    """            const Semantics(
              header: true,
              child: Text('要約', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < lines.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Semantics(
                  label: '要約 ${index + 1}。${lines[index]}',
                  child: Text('${index + 1}. ${lines[index]}'),
                ),
              ),
""",
)

replace_once(
    "lib/screens/comparison_screen.dart",
    """              title: Text(snapshot.contractorName),
              subtitle: Text(
                '提示総額: ${_yen(snapshot.totalAmountYen)}\\n'
                '見積内: ${snapshot.includedCategoryCount}カテゴリ / '
                '別途: ${snapshot.separateCategoryNames.length}件 / '
                '任意: ${snapshot.optionalCategoryNames.length}件\\n'
                '含有不明: ${snapshot.unknownCategoryNames.length}カテゴリ / '
                '不確実点: ${snapshot.uncertaintyCount}件',
              ),
""",
    """              title: Semantics(
                header: true,
                child: Text(snapshot.contractorName),
              ),
              subtitle: Semantics(
                label:
                    '提示総額 ${_yen(snapshot.totalAmountYen)}。'
                    '見積内 ${snapshot.includedCategoryCount}カテゴリ。'
                    '別途 ${snapshot.separateCategoryNames.length}件。'
                    '任意 ${snapshot.optionalCategoryNames.length}件。'
                    '含有不明 ${snapshot.unknownCategoryNames.length}カテゴリ。'
                    '不確実点 ${snapshot.uncertaintyCount}件。',
                child: ExcludeSemantics(
                  child: Text(
                    '提示総額: ${_yen(snapshot.totalAmountYen)}\\n'
                    '見積内: ${snapshot.includedCategoryCount}カテゴリ / '
                    '別途: ${snapshot.separateCategoryNames.length}件 / '
                    '任意: ${snapshot.optionalCategoryNames.length}件\\n'
                    '含有不明: ${snapshot.unknownCategoryNames.length}カテゴリ / '
                    '不確実点: ${snapshot.uncertaintyCount}件',
                  ),
                ),
              ),
""",
)

replace_once(
    "lib/screens/comparison_screen.dart",
    """                    title: Text(cell.contractorName),
                    leading: Icon(_statusIcon(cell.inclusionStatus)),
                    subtitle: Text(
                      '${cell.inclusionStatus.labelJa}\\n'
                      '金額: ${_amount(cell.amountYen)} / '
                      '数量: ${_quantity(cell.quantity, cell.unit)}\\n'
                      '仕様: ${cell.specification ?? "未入力"}'
                      '${cell.uncertaintyReasons.isEmpty ? "" : "\\n確認: ${cell.uncertaintyReasons.join(" / ")}"}',
                    ),
""",
    """                    title: Semantics(
                      header: true,
                      child: Text(cell.contractorName),
                    ),
                    leading: Icon(
                      _statusIcon(cell.inclusionStatus),
                      semanticLabel: '',
                    ),
                    subtitle: Semantics(
                      label:
                          '${cell.contractorName}。'
                          '${cell.inclusionStatus.labelJa}。'
                          '金額 ${_amount(cell.amountYen)}。'
                          '数量 ${_quantity(cell.quantity, cell.unit)}。'
                          '仕様 ${cell.specification ?? "未入力"}。'
                          '${cell.uncertaintyReasons.isEmpty ? "" : "確認 ${cell.uncertaintyReasons.join("、")}。"}',
                      child: ExcludeSemantics(
                        child: Text(
                          '${cell.inclusionStatus.labelJa}\\n'
                          '金額: ${_amount(cell.amountYen)} / '
                          '数量: ${_quantity(cell.quantity, cell.unit)}\\n'
                          '仕様: ${cell.specification ?? "未入力"}'
                          '${cell.uncertaintyReasons.isEmpty ? "" : "\\n確認: ${cell.uncertaintyReasons.join(" / ")}"}',
                        ),
                      ),
                    ),
""",
)

# ---------------------------------------------------------------------------
# Home screen semantics and concise labels
# ---------------------------------------------------------------------------
replace_once(
    "lib/screens/home_screen.dart",
    """/// ホーム画面 - 案件一覧、新規作成、検索、削除。
""",
    """/// ファイルパス: lib/screens/home_screen.dart
/// 目的: 案件一覧、検索、追加、削除への入口を提供する。
/// 存在理由: 利用者が比較対象の案件を選ぶ起点画面のため。
/// 関連ファイル: requirements_comparison_shell.dart, settings_screen.dart, project_repository.dart
""",
)

replace_once(
    "lib/screens/home_screen.dart",
    """        title: const Text('相見積もり比較'),
""",
    """        title: const Text('比較'),
""",
)

replace_once(
    "lib/screens/home_screen.dart",
    """                  FilledButton.icon(
                    key: const ValueKey('create-project-button'),
                    onPressed: () async {
                      await HapticService.lightImpact();
                      if (mounted) await _showCreateDialog();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('新しい案件を作成'),
                  ),
""",
    """                  Semantics(
                    button: true,
                    label: '案件を追加',
                    child: ExcludeSemantics(
                      child: FilledButton.icon(
                        key: const ValueKey('create-project-button'),
                        onPressed: () async {
                          await HapticService.lightImpact();
                          if (mounted) await _showCreateDialog();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('追加'),
                      ),
                    ),
                  ),
""",
)

replace_once(
    "lib/screens/home_screen.dart",
    """                      prefixIcon: const Icon(Icons.search),
""",
    """                      prefixIcon: const Icon(
                        Icons.search,
                        semanticLabel: '検索',
                      ),
""",
)

replace_once(
    "lib/screens/home_screen.dart",
    """                               icon: const Icon(Icons.clear),
""",
    """                               icon: const Icon(
                                 Icons.clear,
                                 semanticLabel: '検索をクリア',
                               ),
""",
)

replace_once(
    "lib/screens/home_screen.dart",
    """                         leading: const Icon(Icons.error_outline),
""",
    """                         leading: const Icon(
                           Icons.error_outline,
                           semanticLabel: 'エラー',
                         ),
""",
)

replace_once(
    "lib/screens/home_screen.dart",
    """                           icon: const Icon(Icons.refresh),
""",
    """                           icon: const Icon(
                             Icons.refresh,
                             semanticLabel: '再読み込み',
                           ),
""",
)

replace_once(
    "lib/screens/home_screen.dart",
    """                           child: Icon(
                             Icons.delete_outline,
                             color: Theme.of(
                               context,
                             ).colorScheme.onErrorContainer,
                           ),
""",
    """                           child: Icon(
                             Icons.delete_outline,
                             semanticLabel: '削除',
                             color: Theme.of(
                               context,
                             ).colorScheme.onErrorContainer,
                           ),
""",
)

replace_once(
    "lib/screens/home_screen.dart",
    """    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: const CircleAvatar(child: Icon(Icons.folder_outlined)),
        title: Text(
          project.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${project.status.labelJa}・見積 ${project.quotes.length}社\\n'
          '要望差異と不明点を確認',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
      ),
    );
""",
    """    return Semantics(
      button: true,
      label:
          '${project.name}。${project.status.labelJa}。'
          '見積 ${project.quotes.length}社。'
          '開く。左にスワイプして削除できます。',
      child: ExcludeSemantics(
        child: Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            onTap: onTap,
            leading: const CircleAvatar(child: Icon(Icons.folder_outlined)),
            title: Text(
              project.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${project.status.labelJa}・見積 ${project.quotes.length}社\\n'
              '要望差異と不明点を確認',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      ),
    );
""",
)

# ---------------------------------------------------------------------------
# Quote input/edit screen semantics and concise labels
# ---------------------------------------------------------------------------
replace_once(
    "lib/screens/quote_input_screen.dart",
    """/// ファイルパス: lib/screens/quote_input_screen.dart
/// PDF・カメラ・写真から見積を取り込み、OCR結果を確認して保存する画面
""",
    """/// ファイルパス: lib/screens/quote_input_screen.dart
/// 目的: 見積を取り込み、OCR結果と明細を編集して保存する。
/// 存在理由: OCR結果を利用者が確認・修正する編集画面のため。
/// 関連ファイル: ocr_service.dart, project_repository.dart, quote_revision_screen.dart
""",
)

replace_once(
    "lib/screens/quote_input_screen.dart",
    """        title: Text(
          widget.revisionIntent.isRevision ? '改訂見積書を取り込む' : '見積書を取り込む',
        ),
""",
    """        title: const Text('編集'),
""",
)

replace_once(
    "lib/screens/quote_input_screen.dart",
    """            tooltip: '確認して保存',
            onPressed: rawQuote == null || _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
""",
    """            tooltip: '保存',
            onPressed: rawQuote == null || _saving ? null : _save,
            icon: _saving
                ? const Semantics(
                    label: '保存中',
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.save_outlined, semanticLabel: '保存'),
""",
)

replace_once(
    "lib/screens/quote_input_screen.dart",
    """                child: FilledButton.icon(
                  key: const ValueKey('quote-pdf-button'),
                  onPressed: _processing ? null : _pickPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('PDFを読み込み'),
                ),
""",
    """                child: Semantics(
                  button: true,
                  label: 'PDFを読み込み',
                  child: ExcludeSemantics(
                    child: FilledButton.icon(
                      key: const ValueKey('quote-pdf-button'),
                      onPressed: _processing ? null : _pickPdf,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('PDF'),
                    ),
                  ),
                ),
""",
)

replace_once(
    "lib/screens/quote_input_screen.dart",
    """                child: OutlinedButton.icon(
                  key: const ValueKey('quote-photo-button'),
                  onPressed: _processing ? null : _pickPhoto,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('写真を読み込み'),
                ),
""",
    """                child: Semantics(
                  button: true,
                  label: '写真を読み込み',
                  child: ExcludeSemantics(
                    child: OutlinedButton.icon(
                      key: const ValueKey('quote-photo-button'),
                      onPressed: _processing ? null : _pickPhoto,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('写真'),
                    ),
                  ),
                ),
""",
)

replace_once(
    "lib/screens/quote_input_screen.dart",
    """                IconButton(
                  tooltip: '明細を追加',
                  onPressed: _addLineItem,
                  icon: const Icon(Icons.add_circle_outline),
                ),
""",
    """                IconButton(
                  tooltip: '追加',
                  onPressed: _addLineItem,
                  icon: const Icon(
                    Icons.add_circle_outline,
                    semanticLabel: '明細を追加',
                  ),
                ),
""",
)

replace_once(
    "lib/screens/quote_input_screen.dart",
    """                      OutlinedButton.icon(
                        onPressed: _addLineItem,
                        icon: const Icon(Icons.add),
                        label: const Text('明細を手動追加'),
                      ),
""",
    """                      Semantics(
                        button: true,
                        label: '明細を追加',
                        child: ExcludeSemantics(
                          child: OutlinedButton.icon(
                            onPressed: _addLineItem,
                            icon: const Icon(Icons.add),
                            label: const Text('追加'),
                          ),
                        ),
                      ),
""",
)

replace_once(
    "lib/screens/quote_input_screen.dart",
    """            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? '保存中…' : '確認して保存'),
            ),
""",
    """            Semantics(
              button: true,
              label: '見積を保存',
              child: ExcludeSemantics(
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? '保存中…' : '保存'),
                ),
              ),
            ),
""",
)

replace_once(
    "lib/screens/quote_input_screen.dart",
    """            Text(
              '明細 ${widget.index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton(
              tooltip: '明細を削除',
              onPressed: widget.onRemove,
              icon: const Icon(Icons.delete_outline),
            ),
""",
    """            Semantics(
              header: true,
              child: Text(
                '明細 ${widget.index + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const Spacer(),
            Semantics(
              button: true,
              label: '明細 ${widget.index + 1}を削除',
              child: ExcludeSemantics(
                child: IconButton(
                  tooltip: '削除',
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            ),
""",
)

# ---------------------------------------------------------------------------
# Revision screen semantics and concise labels
# ---------------------------------------------------------------------------
replace_once(
    "lib/screens/quote_revision_screen.dart",
    """/// 見積書の改訂履歴、差分、比較対象選択を表示する画面。
""",
    """/// ファイルパス: lib/screens/quote_revision_screen.dart
/// 目的: 見積の改訂履歴、差分、比較対象を管理する。
/// 存在理由: 同一業者の複数版を安全に選択・比較するため。
/// 関連ファイル: quote_input_screen.dart, quote_revision_repository.dart, revision_comparison_screen.dart
""",
)

replace_once(
    "lib/screens/quote_revision_screen.dart",
    """            child: const Text('見積書を取り込む'),
""",
    """            child: const Text('取り込む'),
""",
)

replace_once(
    "lib/screens/quote_revision_screen.dart",
    """        title: const Text('見積書の改訂履歴'),
""",
    """        title: const Text('改訂'),
""",
)

replace_once(
    "lib/screens/quote_revision_screen.dart",
    """            tooltip: '選択した改訂版を比較',
            onPressed: _loading ? null : _compareSelected,
            icon: const Icon(Icons.compare_arrows_outlined),
""",
    """            tooltip: '比較',
            onPressed: _loading ? null : _compareSelected,
            icon: const Icon(
              Icons.compare_arrows_outlined,
              semanticLabel: '選択した改訂版を比較',
            ),
""",
)

replace_once(
    "lib/screens/quote_revision_screen.dart",
    """                      OutlinedButton.icon(
                        onPressed: _registerNewContractor,
                        icon: const Icon(Icons.person_add_alt_outlined),
                        label: const Text('新規業者として登録'),
                      ),
""",
    """                      Semantics(
                        button: true,
                        label: '新規業者として登録',
                        child: ExcludeSemantics(
                          child: OutlinedButton.icon(
                            onPressed: _registerNewContractor,
                            icon: const Icon(Icons.person_add_alt_outlined),
                            label: const Text('新規'),
                          ),
                        ),
                      ),
""",
)

replace_once(
    "lib/screens/quote_revision_screen.dart",
    """                      FilledButton.icon(
                        onPressed: _revisions.isEmpty
                            ? null
                            : _registerExistingRevision,
                        icon: const Icon(Icons.history_outlined),
                        label: const Text('既存見積の改訂版として登録'),
                      ),
""",
    """                      Semantics(
                        button: true,
                        label: '既存見積の改訂版として登録',
                        child: ExcludeSemantics(
                          child: FilledButton.icon(
                            onPressed: _revisions.isEmpty
                                ? null
                                : _registerExistingRevision,
                            icon: const Icon(Icons.history_outlined),
                            label: const Text('改訂'),
                          ),
                        ),
                      ),
""",
)

replace_once(
    "lib/screens/quote_revision_screen.dart",
    """                  FilledButton.icon(
                    onPressed: groups.isEmpty ? null : _compareSelected,
                    icon: const Icon(Icons.compare_arrows_outlined),
                    label: Text('選択した${_selectedRevisions.length}件を比較'),
                  ),
""",
    """                  Semantics(
                    button: true,
                    label: '選択した${_selectedRevisions.length}件を比較',
                    child: ExcludeSemantics(
                      child: FilledButton.icon(
                        onPressed: groups.isEmpty ? null : _compareSelected,
                        icon: const Icon(Icons.compare_arrows_outlined),
                        label: Text('比較（${_selectedRevisions.length}件）'),
                      ),
                    ),
                  ),
""",
)

replace_once(
    "lib/screens/quote_revision_screen.dart",
    """        title: Text(latest.contractorName),
""",
    """        title: Semantics(
          header: true,
          child: Text(latest.contractorName),
        ),
""",
)

replace_once(
    "lib/screens/quote_revision_screen.dart",
    """              leading: Icon(
                selectedRevisionId == ordered[index].id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text('第${ordered[index].revisionNumber}版'),
""",
    """              leading: Icon(
                selectedRevisionId == ordered[index].id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                semanticLabel: selectedRevisionId == ordered[index].id
                    ? '比較対象に選択済み'
                    : '比較対象に未選択',
              ),
              title: Semantics(
                header: true,
                child: Text('第${ordered[index].revisionNumber}版'),
              ),
""",
)

replace_once(
    "lib/screens/quote_revision_screen.dart",
    """                tooltip: 'この版から新しい改訂版を作成',
                onPressed: () => onCreateRevision(ordered[index]),
                icon: const Icon(Icons.note_add_outlined),
""",
    """                tooltip: '改訂',
                onPressed: () => onCreateRevision(ordered[index]),
                icon: const Icon(
                  Icons.note_add_outlined,
                  semanticLabel: 'この版から新しい改訂版を作成',
                ),
""",
)

print('Sprint 3 source changes applied.')
