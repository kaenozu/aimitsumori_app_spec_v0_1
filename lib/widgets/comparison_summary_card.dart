/// ファイルパス: lib/widgets/comparison_summary_card.dart
/// 目的: 比較結果の要約をアクセシブルなカードとして表示する。
/// 存在理由: 重要な比較結果を視覚表示と読み上げの両方で理解できるようにするため。
library;

import 'package:flutter/material.dart';

class ComparisonSummaryCard extends StatelessWidget {
  const ComparisonSummaryCard({super.key, required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '比較結果の要約 ${lines.length}件',
      explicitChildNodes: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                label: '比較結果の要約',
                child: const Text(
                  '要約',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              if (lines.isEmpty)
                Semantics(label: '要約はありません', child: const Text('要約はありません。'))
              else
                for (var index = 0; index < lines.length; index++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: index == lines.length - 1 ? 0 : 4,
                    ),
                    child: Semantics(
                      label: '要約 ${index + 1}。${lines[index]}',
                      excludeSemantics: true,
                      child: Text('${index + 1}. ${lines[index]}'),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
