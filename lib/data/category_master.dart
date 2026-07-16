/// ファイルパス: lib/data/category_master.dart
/// 外構工事18カテゴリのマスターデータ
/// 関連ファイル: lib/models.dart

import '../models.dart';

class CategoryMaster {
  CategoryMaster._();

  static final List<CategoryDefinition> categories = [
    const CategoryDefinition('concrete', 1, '土間コンクリート', true, true),
    const CategoryDefinition('gravel_paving', 2, '砂利・舗装', true, true),
    const CategoryDefinition('carport', 3, 'カーポート', true, true),
    const CategoryDefinition('fence', 4, 'フェンス', true, true),
    const CategoryDefinition('gate', 5, '門柱・門扉', true, true),
    const CategoryDefinition('approach', 6, 'アプローチ', true, true),
    const CategoryDefinition('earthwork', 7, '造成・掘削', true, false),
    const CategoryDefinition('soil_disposal', 8, '残土処分', true, false),
    const CategoryDefinition('drainage', 9, '排水', true, true),
    const CategoryDefinition('lighting', 10, '照明・電気', true, true),
    const CategoryDefinition('planting', 11, '植栽', true, true),
    const CategoryDefinition('demolition', 12, '解体・撤去', true, false),
    const CategoryDefinition('protection', 13, '養生', false, false),
    const CategoryDefinition('machinery_transport', 14, '重機回送', false, false),
    const CategoryDefinition('overhead', 15, '諸経費', false, false),
    const CategoryDefinition('application', 16, '申請', false, false),
    const CategoryDefinition('discount', 17, '値引き', false, false),
    const CategoryDefinition('tax', 18, '消費税', false, false),
  ];

  static final Map<String, CategoryDefinition> _byId = {
    for (final c in categories) c.id: c,
  };

  static CategoryDefinition? find(String id) => _byId[id];

  static CategoryDefinition require(String id) {
    final c = find(id);
    if (c == null) throw ArgumentError('Unknown categoryId: $id');
    return c;
  }
}
