
import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../services/task_service.dart';
import '../../services/task_notification_service.dart';
import 'task_form_screen.dart';
import '../../models/subject.dart';
import '../../services/subject_service.dart';

class TaskDetailsScreen extends StatefulWidget {
  final Task task;

  const TaskDetailsScreen({
    super.key,
    required this.task,
  });

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  final _service = TaskService();
  String? _subjectName;
  late Task _task;
  bool _loading = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _loadSubjectName();
  }
  
  Future<void> _loadSubjectName() async {
  if (_task.subjectId == null) {
    if (mounted) {
      setState(() => _subjectName = 'No subject');
    }
    return;
  }

  final result = await SubjectService.getSubjects();

  if (!mounted) return;

  if (result.success) {
    final subjects = result.subjects.where(
      (subject) => subject.id == _task.subjectId,
    );

    setState(() {
      _subjectName = subjects.isNotEmpty
          ? subjects.first.name
          : 'Subject unavailable';
    });
  } else {
    setState(() => _subjectName = 'Subject unavailable');
  }
}

  Future<void> _refresh() async {
    setState(() => _loading = true);

    final result = await _service.getTask(_task.id);

    if (!mounted) return;

    setState(() {
      _loading = false;
      if (result.success && result.task != null) {
        _task = result.task!;
      }
    });

    if (result.success && result.task != null) {
      await TaskNotificationService.scheduleTaskReminders(result.task!);
    }
  }

  Future<void> _edit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(task: _task),
      ),
    );

    if (changed == true && mounted) {
      await _refresh();
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('Delete "${_task.title}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);

    final result = await _service.deleteTask(_task.id);

    if (!mounted) return;

    setState(() => _deleting = false);

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      return;
    }

    await TaskNotificationService.cancelTaskReminders(_task.id);

    if (!mounted) return;

    Navigator.pop(context, true);
  }

  Widget _detail(String label, String value, IconData icon) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label, style: const TextStyle(color: Colors.grey)),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task details'),
        actions: [
          IconButton(
            onPressed: _edit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            onPressed: _deleting ? null : _delete,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  _task.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                if (_task.description.isNotEmpty)
                  Text(
                    _task.description,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                const Divider(height: 32),
                _detail('Status', _task.status, Icons.check_circle_outline),
                _detail('Priority', _task.priority, Icons.flag_outlined),
                _detail(
                  'Deadline',
                  _task.dueDate ?? 'No deadline',
                  Icons.calendar_month,
                ),
                _detail(
                  'Subject',
                  _subjectName ?? 'Loading subject...',
                  Icons.menu_book_outlined,
                ),
                if (_task.createdAt != null)
                  _detail('Created', _task.createdAt!, Icons.access_time),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _edit,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit task'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _deleting ? null : _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete task'),
                ),
              ],
            ),
    );
  }
}
