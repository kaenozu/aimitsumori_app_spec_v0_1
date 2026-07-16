/// 各社の見積と案件要望の差異・不明点を表示する画面。
library;

import 'package:flutter/material.dart';

import '../data/category_master.dart';
import '../models.dart';
import '../normalizer.dart';
import '../question_generator.dart';
import '../repositories/project_repository.dart';
import '../repositories/project_requirement_repository.dart';
import '../requirements_models.dart';
import '../services/requirements_engine.dart';
import 'requirements_checklist_screen.dart';

class RequirementsComparisonScreen extends StatefulWidget {
  const RequirementsComparisonScreen({
    super.key,
    required this.project,
    this.projectRepository,
    this.repository,
  });

  final Project project;
  final ProjectRepository? projectRepository;
  final ProjectRequirementRepository? repository;

  @override
  State<RequirementsComparisonScreen> createState() =>
      _RequirementsComparisonScreenState();
}

class _RequirementsComparisonScreenState
    extends State<RequirementsComparisonScreen> {
  ProjectRequirementRepository get _repository =>
      widget.repository ?? ProjectRequirementRepository.instance;

  late Project _project = widget.project;
  List<ProjectRequirement> _requirements = const [];
  List<RequirementAssessment> _assessments = const [];
  List<ClarificationQuestion> _questions = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final projectRepository =
          widget.projectRepository ?? ProjectRepository.instance;
      final project =
          await projectRepository.getProject(widget.project.id) ?? widget.project;
      final requirements = await _repository.getRequirements(project.id);
      final normalized = Normalizer().normalize(project);
      final assessments = const RequirementsEngine().evaluate(
        requirements: requirements,
        quotes: normalized,
      );
      final questions = QuestionGenerator()
          .generate(
            project: project,
            normalizedQuotes: normalized,
            requirements: requirements,
          )
          .where(
            (question) => question.templateKey.startsWith('REQUIREMENT_'),
          )
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _project = project;
        _requirements = requirements;
        _assessments = assessments;
        _questions = questions;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _editRequirements() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => RequirementsChecklistScreen(
          project: _project,
          repository: _repository,
        ),
      ),
    );
    if (mounted) await _load();
  }

  bool get _hasConfiguredRequirement =>
      _requirements.any((requirement) => requirement.isConfigured);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('要望との差異'),
        actions: [
          IconButton(
            tooltip: '要望を編集',
            onPressed: _editRequirements,
            icon: const Icon(Icons.tune_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 280),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    '総合点やランキングは付けず、要望との差異と確認が必要な点だけを表示します。',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _editRequirements,
                    icon: const Icon(Icons.checklist_outlined),
                    label: const Text('18カテゴリの要望を編集'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: ListTile(
                        leading: const Icon(Icons.error_outline),
                        title: Text(_error!),
                        trailing: IconButton(
                          tooltip: '再読み込み',
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                        ),
                      ),
                    ),
                  ] else if (!_hasConfiguredRequirement) ...[
                    const SizedBox(height: 12),
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.info_outline),
                        title: Text('要望がまだ設定されていません。'),
                        subtitle: Text(
                          '必須・あればよい・不要を設定すると、各社との差異を表示します。',
                        ),
                      ),
                    ),
                  ] else if (_project.quotes.isEmpty) ...[
                    const SizedBox(height: 12),
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.description_outlined),
                        title: Text('比較する見積がありません。'),
                        subtitle: Text(
                          '見積書を追加すると、各社の要望充足状況を表示します。',
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    for (final quote in _project.quotes) ...[
                      _ContractorRequirementCard(
                        contractorName: quote.contractorName,
                        assessments: _assessments
                            .where((item) => item.quoteId == quote.id)
                            .where(_shouldDisplay)
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '要望から生成した確認質問 (${_questions.length}件)',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    if (_questions.isEmpty)
                      const Card(
                        child: ListTile(title: Text('要望に基づく追加確認はありません。')),
                      )
                    else
                      for (final question in _questions)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.question_answer_outlined),
                            title: Text(question.contractorName ?? '業者'),
                            subtitle: SelectableText(question.questionText),
                          ),
                        ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
      ),
    );
  }

  bool _shouldDisplay(RequirementAssessment assessment) {
    return assessment.requirement.priority == RequirementPriority.required ||
        assessment.requirement.priority == RequirementPriority.unnecessary ||
        assessment.mismatches.isNotEmpty;
  }
}

class _ContractorRequirementCard extends StatelessWidget {
  const _ContractorRequirementCard({
    required this.contractorName,
    required this.assessments,
  });

  final String contractorName;
  final List<RequirementAssessment> assessments;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                contractorName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          if (assessments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('表示対象の差異・不明点はありません。'),
            )
          else
            for (var index = 0; index < assessments.length; index++) ...[
              _AssessmentTile(assessment: assessments[index]),
              if (index != assessments.length - 1) const Divider(height: 1),
            ],
        ],
      ),
    );
  }
}

class _AssessmentTile extends StatelessWidget {
  const _AssessmentTile({required this.assessment});

  final RequirementAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final category = CategoryMaster.require(assessment.requirement.categoryId);
    final details = [
      assessment.status.labelJa,
      for (final mismatch in assessment.mismatches) mismatch.message,
      if (assessment.requirement.note?.trim().isNotEmpty == true)
        '要望メモ: ${assessment.requirement.note!.trim()}',
    ];
    return ListTile(
      leading: Icon(_icon(assessment.status)),
      title: Text(category.nameJa),
      subtitle: Text(details.join('\n')),
      isThreeLine: details.length > 1,
    );
  }

  IconData _icon(RequirementCoverageStatus status) => switch (status) {
        RequirementCoverageStatus.requiredIncluded => Icons.check_circle_outline,
        RequirementCoverageStatus.requiredSeparate => Icons.add_circle_outline,
        RequirementCoverageStatus.requiredMissing => Icons.help_outline,
        RequirementCoverageStatus.unnecessaryIncluded =>
          Icons.warning_amber_outlined,
        RequirementCoverageStatus.optionalIncluded => Icons.check_circle_outline,
        RequirementCoverageStatus.optionalMissing => Icons.info_outline,
        RequirementCoverageStatus.noIssue => Icons.remove_circle_outline,
        RequirementCoverageStatus.unset => Icons.help_outline,
      };
}
