
import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../services/task_service.dart';
import '../../services/task_notification_service.dart';

class TaskFormScreen extends StatefulWidget {
  final int? subjectId;
  final Task? task;

  const TaskFormScreen({
    super.key,
    this.subjectId,
    this.task,
  });

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = TaskService();

  late final TextEditingController _title;
  late final TextEditingController _description;

  late String _priority;
  late String _status;
  DateTime? _deadline;

  bool _saving = false;

  bool get _editing => widget.task != null;

  @override
  void initState() {
    super.initState();

    final task = widget.task;

    _title = TextEditingController(text: task?.title ?? '');
    _description = TextEditingController(
      text: task?.description ?? '',
    );

    _priority = task?.priority ?? 'MEDIUM';
    _status = task?.status ?? 'PENDING';

    if (task?.dueDate != null) {
      _deadline = DateTime.tryParse(task!.dueDate!);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');

    return '${date.year}-${two(date.month)}-${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}:00';
  }

  Future<void> _chooseDeadline() async {
    final now = DateTime.now();
    final initial = _deadline ?? now.add(const Duration(days: 1));

    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 10),
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );

    if (time == null || !mounted) return;

    setState(() {
      _deadline = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final deadline = _deadline == null ? null : _formatDate(_deadline!);

    final TaskOperationResult result;

    if (_editing) {
      result = await _service.updateTask(
        taskId: widget.task!.id,
        subjectId: widget.task!.subjectId,
        title: _title.text.trim(),
        description: _description.text.trim(),
        dueDate: deadline,
        priority: _priority,
        status: _status,
      );
    } else {
      result = await _service.createTask(
        subjectId: widget.subjectId,
        title: _title.text.trim(),
        description: _description.text.trim(),
        dueDate: deadline,
        priority: _priority,
        status: _status,
      );
    }

    if (!mounted) return;

    setState(() => _saving = false);

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      return;
    }

    Task? savedTask = result.task;

    if (savedTask == null && _editing) {
      final refreshed = await _service.getTask(widget.task!.id);
      if (refreshed.success) savedTask = refreshed.task;
    }

    if (savedTask != null) {
      await TaskNotificationService.scheduleTaskReminders(savedTask);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_editing ? 'Task updated' : 'Task created'),
      ),
    );

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit task' : 'Create task'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Task title',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty
                      ? 'Enter a title'
                      : null,
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _description,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              decoration: const InputDecoration(
                labelText: 'Priority',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'LOW', child: Text('Low')),
                DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
                DropdownMenuItem(value: 'HIGH', child: Text('High')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _priority = value);
              },
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'PENDING',
                  child: Text('Pending'),
                ),
                DropdownMenuItem(
                  value: 'IN_PROGRESS',
                  child: Text('In progress'),
                ),
                DropdownMenuItem(value: 'DONE', child: Text('Done')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _status = value);
              },
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _chooseDeadline,
              icon: const Icon(Icons.calendar_month),
              label: Text(
                _deadline == null
                    ? 'Choose deadline'
                    : _formatDate(_deadline!),
              ),
            ),
            if (_deadline != null)
              TextButton(
                onPressed: () => setState(() => _deadline = null),
                child: const Text('Remove deadline'),
              ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const CircularProgressIndicator()
                  : Text(_editing ? 'Save changes' : 'Create task'),
            ),
          ],
        ),
      ),
    );
  }
}
