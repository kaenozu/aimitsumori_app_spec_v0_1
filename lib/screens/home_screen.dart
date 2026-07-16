/// ファイルパス: lib/screens/home_screen.dart
/// ホーム画面 - SQLiteに保存された案件一覧と新規作成
/// 関連ファイル: lib/main.dart, lib/screens/comparison_screen.dart
library;

import 'package:flutter/material.dart';

import '../models.dart';
import '../repositories/project_repository.dart';
import '../services/ad_service.dart';
import 'comparison_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.repository,
    this.adService,
  });

  final ProjectRepository? repository;
  final AdService? adService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Project> _projects = const [];
  bool _loading = true;
  String? _error;

  ProjectRepository get _repository =>
      widget.repository ?? ProjectRepository.instance;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _loading = true;
      _error = null;
    });
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

  Future<void> _createProject(String name) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final project = Project(
      id: 'project-$now',
      name: name,
      status: ProjectStatus.draft,
      createdAtEpochMillis: now,
      updatedAtEpochMillis: now,
    );
    await _repository.saveProject(project);
    await _loadProjects();
  }

  Future<void> _openProject(Project project) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ComparisonScreen(
          project: project,
          repository: _repository,
          adService: widget.adService,
        ),
      ),
    );
    await _loadProjects();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('相見積もり比較')),
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
                  const Text(
                    '総合点や順位ではなく、価格・範囲・不明点を並べて確認します。',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _showCreateDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('新しい案件を作成'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Theme.of(context).colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: '再読み込み',
                              onPressed: _loadProjects,
                              icon: const Icon(Icons.refresh),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_projects.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(Icons.folder_open_outlined, size: 40),
                            SizedBox(height: 8),
                            Text('案件はまだありません。'),
                            SizedBox(height: 4),
                            Text('案件を作成して、見積書を取り込んでください。'),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._projects.map(
                      (project) => _ProjectCard(
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
          controller: controller,
          decoration: const InputDecoration(
            labelText: '案件名',
            hintText: '例: 新築外構工事',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('作成'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || !mounted) return;

    try {
      await _createProject(name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('案件を作成しました。')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    super.key,
    required this.project,
    required this.onTap,
  });

  final Project project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '状態: ${project.status.labelJa}　見積: ${project.quotes.length}社',
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
