import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/task_list_vm.dart';
import '../widgets/task_tile.dart';
import 'task_view.dart';
import '../widgets/input_field.dart';
import '../services/share_service.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  final ScrollController scrollController = ScrollController();
  final TextEditingController titleController = TextEditingController();
  late PageController pageController;

  @override
  void initState() {
    super.initState();
    pageController = PageController();
    scrollController.addListener(() {
      if (scrollController.position.pixels > scrollController.position.maxScrollExtent - 200) {
        ref.read(taskListViewModelProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    titleController.dispose();
    pageController.dispose();
    super.dispose();
  }

  Future<void> _createTask() async {
    final title = titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: const Text('Please enter a task title'), backgroundColor: Theme.of(context).colorScheme.error));
      return;
    }

    try {
      await ref.read(taskListViewModelProvider.notifier).createTask(title, '');
      titleController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Theme.of(context).colorScheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(taskListViewModelProvider);
    final isLoadingMore = ref.watch(taskListLoadingMoreProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MyTodo'),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Tooltip(
                message: 'Refresh tasks',
                child: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    ref.invalidate(taskListViewModelProvider);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Create New Task', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  InputField(
                    controller: titleController,
                    hint: 'Task title',
                    onSubmitted: (_) => _createTask(),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Task title cannot be empty';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: tasksAsync.when(
                data: (tasks) {
                  if (tasks.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.task_alt, size: 64, color: Theme.of(context).primaryColor.withOpacity(0.3)),
                            const SizedBox(height: 16),
                            Text('No tasks yet', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Text('Create your first task above', style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: tasks.length,
                    itemBuilder: (_, i) {
                      final t = tasks[i];
                      return TaskTile(
                        title: t.title,
                        subtitle: t.content,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaskView(taskId: t.id))),
                        onShare: () => ShareService.shareTaskLink(t.id),
                        onDelete: () => showDeleteConfirmation(taskId: t.id, title: t.title),
                      );
                    },
                  );
                },
                loading: () => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text('Loading tasks...', style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ),
                error: (e, st) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                        const SizedBox(height: 16),
                        Text('Error loading tasks', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(e.toString(), style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            ref.invalidate(taskListViewModelProvider);
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (isLoadingMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 8),
                      Text('Loading more tasks...', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }

  void showDeleteConfirmation({required String taskId, required String title}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task?'),
        content: Text('Delete "$title"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(taskListViewModelProvider.notifier).deleteTask(taskId);
            },
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
