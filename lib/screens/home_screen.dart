/// ファイルパス: lib/screens/home_screen.dart
/// ホーム画面 - 案件一覧と新規作成ボタン
/// 関連ファイル: lib/main.dart, lib/screens/comparison_screen.dart

import 'package:flutter/material.dart';
import '../models.dart';
import '../data/sample_data.dart';
import 'comparison_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Project> _projects = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final sample = SampleData.project();
    setState(() {
      _projects.add(sample);
      _loaded = true;
    });
  }

  void _createProject(String name) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final project = Project(
      id: 'project-$now',
      name: name,
      status: ProjectStatus.draft,
      createdAtEpochMillis: now,
      updatedAtEpochMillis: now,
    );
    setState(() => _projects.insert(0, project));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('相見積もり比較')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  '総合点や順位ではなく、価格・範囲・不明点を並べて確認します。',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => _showCreateDialog(context),
                  child: const Text('新しい案件を作成'),
                ),
                const SizedBox(height: 16),
                if (_projects.isEmpty)
                  const Text('案件はまだありません。')
                else
                  ..._projects.map((p) => _ProjectCard(
                        project: p,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ComparisonScreen(project: p),
                            ),
                          );
                        },
                      )),
              ],
            ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                _createProject(name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('作成'),
          ),
        ],
      ),
    );
    controller.dispose();
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final VoidCallback onTap;

  const _ProjectCard({required this.project, required this.onTap});

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
                    Text(project.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('状態: ${project.status.labelJa}　見積: ${project.quotes.length}社'),
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
