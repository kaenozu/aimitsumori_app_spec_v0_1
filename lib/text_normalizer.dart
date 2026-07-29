/// ファイルパス: lib/text_normalizer.dart
/// 目的: OCR・手入力テキストの表記ゆれを安全に正規化する。
/// 存在理由: 全角英数、長音、括弧類の変換規則を共有するため。
library;

class TextNormalizer {
  const TextNormalizer._();

  static String? normalize(String? input) {
    if (input == null) {
      return null;
    }

    var normalized = String.fromCharCodes(
      input.runes.map((rune) {
        if (rune == 0x3000) {
          return 0x20;
        }
        if (rune >= 0xff01 && rune <= 0xff5e) {
          return rune - 0xfee0;
        }
        return rune;
      }),
    );

    normalized = normalized
        .replaceAll(RegExp(r'[―−‐-–—]'), '-')
        .replaceAll('￥', '¥')
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
