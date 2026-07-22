/// ホーム画面 - 案件一覧、新規作成、検索、削除。
library;

import 'package:flutter/material.dart';

import '../data/sample_data.dart';
import '../models.dart';
import '../repositories/project_repository.dart';
import '../repositories/project_requirement_repository.dart';
import '../repositories/quote_revision_repository.dart';
import '../services/ad_service.dart';
import '../services/haptic_service.dart';
import '../services/ocr_review_store.dart';
import 'requirements_checklist_screen.dart';
import 'requirements_comparison_shell.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.repository,
    this.requirementRepository,
    this.quoteRevisionRepository,
    this.adService,
    this.reviewStore,
    this.darkModeEnabled = false,
    this.onDarkModeChanged,
  });

  final ProjectRepository? repository;
  final ProjectRequirementRepository? requirementRepository;
  final QuoteRevisionRepository? quoteRevisionRepository;
  final AdService? adService;
  final OcrReviewStore? reviewStore;
  final bool darkModeEnabled;
  final ValueChanged<bool>? onDarkModeChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Project> _projects = const [];
  bool _loading = true;
  String _searchQuery = '';
  String? _error;

  ProjectRepository get _repository =>
      widget.repository ?? ProjectRepository.instance;
  ProjectRequirementRepository get _requirementRepository =>
      widget.requirementRepository ?? ProjectRequirementRepository.instance;

  List<Project> get _filteredProjects {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _projects;
    return _projects
        .where((project) {
          final matchesProject = project.name.toLowerCase().contains(query);
          final matchesContractor = project.quotes.any(
            (quote) => quote.contractorName.toLowerCase().contains(query),
          );
          return matchesProject || matchesContractor;
        })
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final projects = await _repository.getProjects();
      if (!mounted) return;
      setState(() => _projects = projects);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Project> _createProject(String name) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final projectId = 'project-${DateTime.now().microsecondsSinceEpoch}';
    final project = Project(
      id: projectId,
      name: name,
      status: ProjectStatus.draft,
      createdAtEpochMillis: now,
      updatedAtEpochMillis: now,
    );
    await _repository.saveProject(project);
    return project;
  }

  Future<void> _openProject(Project project) async {
    await HapticService.lightImpact();
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _ComparisonHapticGate(
          child: RequirementsComparisonShell(
            project: project,
            projectRepository: _repository,
            requirementRepository: _requirementRepository,
            quoteRevisionRepository: widget.quoteRevisionRepository,
            adService: widget.adService,
          ),
        ),
      ),
    );
    await _loadProjects();
  }

  Future<void> _openSettings() async {
    await HapticService.lightImpact();
    if (!mounted) return;
    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          repository: _repository,
          reviewStore: widget.reviewStore,
          darkModeEnabled: widget.darkModeEnabled,
          onDarkModeChanged: widget.onDarkModeChanged ?? (_) {},
        ),
      ),
    );
    if (deleted != true || !mounted) return;
    await _loadProjects();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('すべての案件データを削除しました。')));
  }

  Future<void> _openSampleProject() async {
    try {
      final sample = SampleData.project();
      await _repository.saveProject(sample);
      await _loadProjects();
      if (!mounted) return;
      await _openProject(sample);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<bool> _confirmDeleteProject(Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('案件を削除しますか？'),
        content: Text('「${project.name}」の見積と比較結果も削除されます。'),
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
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    try {
      await _repository.deleteProject(project.id);
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return false;
    }
  }

  void _onProjectDismissed(Project project) {
    setState(() {
      _projects = _projects
          .where((existing) => existing.id != project.id)
          .toList(growable: false);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('「${project.name}」を削除しました。')));
  }

  void _clearSearch() {
    HapticService.lightImpact();
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  Future<void> _showCreateDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('案件作成'),
        content: TextField(
          key: const ValueKey('project-name-field'),
          controller: controller,
          maxLength: 100,
          decoration: const InputDecoration(
            labelText: '案件名',
            hintText: '例: 新築外構工事',
          ),
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) {
            final trimmed = value.trim();
            if (trimmed.isNotEmpty && trimmed.length <= 100) {
              Navigator.pop(dialogContext, trimmed);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await HapticService.lightImpact();
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () async {
              await HapticService.lightImpact();
              final value = controller.text.trim();
              if (value.isNotEmpty &&
                  value.length <= 100 &&
                  dialogContext.mounted) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: const Text('次へ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || !mounted) return;

    try {
      final project = await _createProject(name);
      if (!mounted) return;
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => RequirementsChecklistScreen(
            project: project,
            repository: _requirementRepository,
            creationFlow: true,
          ),
        ),
      );
      if (!mounted) return;
      await _loadProjects();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('案件を作成しました。')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredProjects = _filteredProjects;
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          header: true,
          label: '比較アプリ ホーム',
          child: const Text('比較'),
        ),
        actions: [
          PopupMenuButton<_HomeMenuAction>(
            tooltip: 'メニュー',
            onSelected: (action) {
              if (action == _HomeMenuAction.settings) _openSettings();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _HomeMenuAction.settings,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.settings_outlined),
                  title: Text('設定'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProjects,
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
                  Semantics(
                    label: '総合点や順位ではなく、価格・範囲・要望との差・不明点を並べて確認します。',
                    child: const Text(
                      '総合点や順位ではなく、価格・範囲・要望との差・不明点を並べて確認します。',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    button: true,
                    label: '新しい案件を作成',
                    child: FilledButton.icon(
                      key: const ValueKey('create-project-button'),
                      onPressed: () async {
                        await HapticService.lightImpact();
                        if (mounted) await _showCreateDialog();
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('新しい案件を作成'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('project-search-field'),
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      labelText: '案件を検索',
                      hintText: '案件名または業者名',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              key: const ValueKey('project-search-clear'),
                              tooltip: '検索をクリア',
                              onPressed: _clearSearch,
                              icon: const Icon(Icons.clear),
                            ),
                      border: const OutlineInputBorder(),
                    ),
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
                          onPressed: _loadProjects,
                          icon: const Icon(Icons.refresh),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_projects.isEmpty)
                    _EmptyProjectsCard(onTrySample: _openSampleProject)
                  else if (filteredProjects.isEmpty)
                    _EmptySearchCard(query: _searchQuery.trim())
                  else
                    for (final project in filteredProjects)
                      Dismissible(
                        key: ValueKey('project-dismiss-${project.id}'),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) => _confirmDeleteProject(project),
                        onDismissed: (_) => _onProjectDismissed(project),
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          alignment: Alignment.centerRight,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.delete_outline,
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                        ),
                        child: _ProjectCard(
                          key: ValueKey('project-card-${project.id}'),
                          project: project,
                          onTap: () => _openProject(project),
                        ),
                      ),
                ],
              ),
      ),
    );
  }

  Future<void> _showCreateDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('案件作成'),
        content: TextField(
          key: const ValueKey('project-name-field'),
          controller: controller,
          decoration: const InputDecoration(
            labelText: '案件名',
            hintText: '例: 新築外構工事',
          ),
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) {
            final trimmed = value.trim();
            if (trimmed.isNotEmpty) Navigator.pop(dialogContext, trimmed);
          },
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await HapticService.lightImpact();
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () async {
              await HapticService.lightImpact();
              final value = controller.text.trim();
              if (value.isNotEmpty && dialogContext.mounted) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: const Text('次へ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || !mounted) return;

    try {
      final project = await _createProject(name);
      if (!mounted) return;
      final openProject = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => RequirementsChecklistScreen(
            project: project,
            repository: _requirementRepository,
            creationFlow: true,
          ),
        ),
      );
      if (!mounted) return;
      await _loadProjects();
      if (!mounted) return;
      if (openProject == true) {
        await _openProject(project);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('案件を作成しました。')));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

enum _HomeMenuAction { settings }

class _EmptyProjectsCard extends StatelessWidget {
  const _EmptyProjectsCard({required this.onTrySample});

  final VoidCallback onTrySample;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '案件はまだありません。新しい案件を作成して見積を追加してください。',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.folder_open_outlined, size: 40, semanticLabel: ''),
              const SizedBox(height: 8),
              Semantics(
                header: true,
                label: '案件はまだありません',
                child: const Text(
                  '案件はまだありません。',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '「新しい案件を作成」から要望を整理し、PDFまたは写真の見積書を追加してください。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Semantics(
                button: true,
                label: 'サンプル比較を試す',
                child: FilledButton.icon(
                  onPressed: onTrySample,
                  icon: const Icon(Icons.play_arrow_outlined),
                  label: const Text('サンプル比較を試す'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySearchCard extends StatelessWidget {
  const _EmptySearchCard({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '「$query」に一致する案件はありません。',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.search_off_outlined, size: 40, semanticLabel: ''),
              const SizedBox(height: 8),
              Text('「$query」に一致する案件はありません。', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({super.key, required this.project, required this.onTap});

  final Project project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${project.name}。${project.status.labelJa}。見積 ${project.quotes.length}社。',
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
            '${project.status.labelJa}・見積 ${project.quotes.length}社\n'
            '要望差異と不明点を確認',
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}

class _ComparisonHapticGate extends StatefulWidget {
  const _ComparisonHapticGate({required this.child});

  final Widget child;

  @override
  State<_ComparisonHapticGate> createState() => _ComparisonHapticGateState();
}

class _ComparisonHapticGateState extends State<_ComparisonHapticGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) HapticService.mediumImpact();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
