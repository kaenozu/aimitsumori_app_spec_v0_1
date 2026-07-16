/// ファイルパス: lib/data/category_master.dart
/// 外構工事18カテゴリのマスターデータ
library;

import '../models.dart';

class CategoryMaster {
  CategoryMaster._();

  static const List<CategoryDefinition> categories = [
    CategoryDefinition('concrete', 1, '土間コンクリート', true, true),
    CategoryDefinition('gravel_paving', 2, '砂利・舗装', true, true),
    CategoryDefinition('carport', 3, 'カーポート', true, true),
    CategoryDefinition('fence', 4, 'フェンス', true, true),
    CategoryDefinition('gate', 5, '門柱・門扉', true, true),
    CategoryDefinition('approach', 6, 'アプローチ', true, true),
    CategoryDefinition('earthwork', 7, '造成・掘削', true, false),
    CategoryDefinition('soil_disposal', 8, '残土処分', true, false),
    CategoryDefinition('drainage', 9, '排水', true, true),
    CategoryDefinition('lighting', 10, '照明・電気', true, true),
    CategoryDefinition('planting', 11, '植栽', true, true),
    CategoryDefinition('demolition', 12, '解体・撤去', true, false),
    CategoryDefinition('protection', 13, '養生', false, false),
    CategoryDefinition('machinery_transport', 14, '重機回送', false, false),
    CategoryDefinition('overhead', 15, '諸経費', false, false),
    CategoryDefinition('application', 16, '申請', false, false),
    CategoryDefinition('discount', 17, '値引き', false, false),
    CategoryDefinition('tax', 18, '消費税', false, false),
  ];

  static final Map<String, CategoryDefinition> _byId = {
    for (final category in categories) category.id: category,
  };

  static CategoryDefinition? find(String id) => _byId[id];

  static CategoryDefinition require(String id) {
    final category = find(id);
    if (category == null) {
      throw ArgumentError.value(id, 'id', 'Unknown categoryId');
    }
    return category;
  }
}
