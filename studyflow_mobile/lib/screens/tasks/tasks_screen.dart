
import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../services/task_service.dart';
import '../../services/subject_service.dart';
import '../../services/task_notification_service.dart';
import 'task_details_screen.dart';
import 'task_form_screen.dart';

class TasksScreen extends StatefulWidget {
  final String title;
  final int? subjectId;

  const TasksScreen({
    super.key,
    this.title = 'My Tasks',
    this.subjectId,
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final TaskService _service = TaskService();
  final TextEditingController _searchController =
      TextEditingController();

  List<Task> _tasks = [];
  Map<int, String> _subjectNames = {};

  bool _loading = true;
  String? _error;
  String _filter = 'ALL';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = widget.subjectId == null
        ? await _service.getTasks()
        : await _service.getTasksBySubjectId(widget.subjectId!);

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _loading = false;
        _error = result.message;
      });
      return;
    }

    Map<int, String> subjectNames = {};

    try {
      final subjectsResult = await SubjectService.getSubjects();

      if (subjectsResult.success) {
        subjectNames = {
          for (final subject in subjectsResult.subjects)
            subject.id: subject.name,
        };
      }
    } catch (_) {
      // Tasks remain available if subject lookup fails.
    }

    if (!mounted) return;

    setState(() {
      _tasks = result.tasks;
      _subjectNames = subjectNames;
      _loading = false;
    });

    for (final task in result.tasks) {
      await TaskNotificationService.scheduleTaskReminders(task);
    }
  }

  String _getSubjectName(Task task) {
    if (task.subjectId == null) {
      return 'No subject';
    }

    return _subjectNames[task.subjectId] ?? 'Subject unavailable';
  }

  List<Task> get _visibleTasks {
    return _tasks.where((task) {
      final matchesFilter =
          _filter == 'ALL' || task.status == _filter;

      final query = _query.toLowerCase();

      final matchesSearch =
          task.title.toLowerCase().contains(query) ||
          task.description.toLowerCase().contains(query);

      return matchesFilter && matchesSearch;
    }).toList();
  }

  Future<void> _createTask() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(
          subjectId: widget.subjectId,
        ),
      ),
    );

    if (changed == true && mounted) {
      await _loadTasks();
    }
  }

  Future<void> _openTask(Task task) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailsScreen(task: task),
      ),
    );

    if (mounted) {
      await _loadTasks();
    }
  }

  Color _priorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'HIGH':
        return Colors.red;
      case 'MEDIUM':
        return Colors.orange;
      case 'LOW':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'DONE':
        return Colors.green;
      case 'IN_PROGRESS':
        return Colors.blue;
      case 'PENDING':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildFilterChip(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _filter == value,
        onSelected: (_) {
          setState(() => _filter = value);
        },
      ),
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openTask(task),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
                ],
              ),
              if (task.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  task.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTag(
                    'Priority: ${task.priority}',
                    _priorityColor(task.priority),
                  ),
                  _buildTag(
                    task.status.replaceAll('_', ' '),
                    _statusColor(task.status),
                  ),
                  _buildTag(
                    _getSubjectName(task),
                    Colors.teal,
                  ),
                ],
              ),
              if (task.dueDate != null &&
                  task.dueDate!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Due: ${task.dueDate}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.task_alt,
            size: 65,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No tasks found',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a task to organize your study work.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _createTask,
            icon: const Icon(Icons.add),
            label: const Text('Create task'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _visibleTasks;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        automaticallyImplyLeading: widget.subjectId != null,
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadTasks,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh tasks',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createTask,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _query = value);
              },
              decoration: InputDecoration(
                hintText: 'Search tasks...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.clear),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('ALL', 'All'),
                _buildFilterChip('PENDING', 'Pending'),
                _buildFilterChip('IN_PROGRESS', 'In progress'),
                _buildFilterChip('DONE', 'Done'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: _loadTasks,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadTasks,
                        child: tasks.isEmpty
                            ? ListView(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height: 350,
                                    child: _emptyState(),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(16),
                                itemCount: tasks.length,
                                itemBuilder: (context, index) {
                                  return _buildTaskCard(tasks[index]);
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}
