/// ファイルパス: lib/screens/requirements_comparison_shell.dart
/// 目的: 比較、要望差異、改訂履歴の3画面を切り替える。
/// 存在理由: 1案件に関する確認機能を共通ナビゲーションへ集約するため。
/// 関連ファイル: comparison_screen.dart, requirements_comparison_screen.dart, quote_revision_screen.dart
library;

import 'package:flutter/material.dart';

import '../models.dart';
import '../repositories/project_repository.dart';
import '../repositories/project_requirement_repository.dart';
import '../services/ad_service.dart';
import 'comparison_screen.dart';
import 'quote_revision_screen.dart';
import 'requirements_comparison_screen.dart';

class RequirementsComparisonShell extends StatefulWidget {
  const RequirementsComparisonShell({
    super.key,
    required this.project,
    this.projectRepository,
    this.requirementRepository,
    this.adService,
  });

  final Project project;
  final ProjectRepository? projectRepository;
  final ProjectRequirementRepository? requirementRepository;
  final AdService? adService;

  @override
  State<RequirementsComparisonShell> createState() =>
      _RequirementsComparisonShellState();
}

class _RequirementsComparisonShellState
    extends State<RequirementsComparisonShell> {
  int _selectedIndex = 0;
  int _requirementsRevision = 0;
  int _historyRevision = 0;

  void _select(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 1) _requirementsRevision += 1;
      if (index == 2) _historyRevision += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          ComparisonScreen(
            project: widget.project,
            repository: widget.projectRepository,
            adService: widget.adService,
          ),
          RequirementsComparisonScreen(
            key: ValueKey('requirements-$_requirementsRevision'),
            project: widget.project,
            projectRepository: widget.projectRepository,
            repository: widget.requirementRepository,
          ),
          QuoteRevisionScreen(
            key: ValueKey('quote-history-$_historyRevision'),
            project: widget.project,
            projectRepository: widget.projectRepository,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.compare_arrows_outlined),
            selectedIcon: Icon(Icons.compare_arrows),
            label: '比較',
          ),
          NavigationDestination(
            icon: Icon(Icons.rule_outlined),
            selectedIcon: Icon(Icons.rule),
            label: '要望',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: '改訂',
          ),
        ],
      ),
    );
  }
}
