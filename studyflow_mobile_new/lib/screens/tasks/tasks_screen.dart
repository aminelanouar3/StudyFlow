
import 'package:flutter/material.dart';

import '../../models/subject.dart';
import '../../models/task.dart';
import '../../services/session_service.dart';
import '../../services/subject_service.dart';
import '../../services/task_service.dart';

class TasksScreen extends StatefulWidget {
  final Subject? subject;

  const TasksScreen({super.key, this.subject});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<StudyTask> _tasks = [];
  List<Subject> _subjects = [];

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  String _statusFilter = 'ALL';
  String _priorityFilter = 'ALL';

  final TextEditingController _searchController = TextEditingController();

  bool get _isSubjectScreen => widget.subject != null;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final token = await SessionService.getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Your session has expired. Please sign in again.');
      }

      final tasks = _isSubjectScreen
          ? await TaskService.getTasksBySubjectId(
              token: token,
              subjectId: widget.subject!.id.toString(),
            )
          : await TaskService.getTasks(token: token);

      final subjects = _isSubjectScreen
          ? [widget.subject!]
          : await SubjectService.getSubjects(token: token);

      if (!mounted) return;

      setState(() {
        _tasks = tasks;
        _subjects = subjects;
        _error = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  List<StudyTask> get _filteredTasks {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = _tasks.where((task) {
      final matchesSearch =
          query.isEmpty || task.title.toLowerCase().contains(query);

      final matchesStatus =
          _statusFilter == 'ALL' || task.status == _statusFilter;

      final matchesPriority =
          _priorityFilter == 'ALL' || task.priority == _priorityFilter;

      return matchesSearch && matchesStatus && matchesPriority;
    }).toList();

    filtered.sort((a, b) {
      final dateA = a.parsedDueDate;
      final dateB = b.parsedDueDate;

      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;

      return dateA.compareTo(dateB);
    });

    return filtered;
  }

  Future<void> _showCreateDialog() async {
    final data = await showDialog<_TaskFormData>(
      context: context,
      builder: (context) => _TaskFormDialog(
        subjects: _subjects,
        fixedSubjectId: widget.subject?.id,
      ),
    );

    if (data == null || !mounted) return;

    await _saveTask(data);
  }

  Future<void> _showEditDialog(StudyTask task) async {
    final data = await showDialog<_TaskFormData>(
      context: context,
      builder: (context) => _TaskFormDialog(
        subjects: _subjects,
        task: task,
        fixedSubjectId: widget.subject?.id,
      ),
    );

    if (data == null || !mounted) return;

    await _saveTask(data, taskId: task.id.toString());
  }

  Future<void> _saveTask(
    _TaskFormData data, {
    String? taskId,
  }) async {
    setState(() {
      _isSaving = true;
    });

    try {
      final token = await SessionService.getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Your session has expired. Please sign in again.');
      }

      final dueDate =
          data.dueDate == null ? null : _formatDateTime(data.dueDate!);

      final subjectId = widget.subject?.id ?? data.subjectId;

      if (taskId == null) {
        await TaskService.createTask(
          token: token,
          subjectId: subjectId,
          title: data.title,
          description: data.description,
          dueDate: dueDate,
          priority: data.priority,
          status: data.status,
        );
      } else {
        await TaskService.updateTask(
          token: token,
          taskId: taskId,
          subjectId: subjectId,
          title: data.title,
          description: data.description,
          dueDate: dueDate,
          priority: data.priority,
          status: data.status,
        );
      }

      if (!mounted) return;

      await _loadData(showLoader: false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            taskId == null
                ? 'Task created successfully.'
                : 'Task updated successfully.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteTask(StudyTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text(
          'Are you sure you want to delete "${task.title}"? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final token = await SessionService.getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Your session has expired. Please sign in again.');
      }

      await TaskService.deleteTask(
        token: token,
        taskId: task.id.toString(),
      );

      if (!mounted) return;

      await _loadData(showLoader: false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task deleted successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _formatDateTime(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${date.year}-'
        '${twoDigits(date.month)}-'
        '${twoDigits(date.day)} '
        '${twoDigits(date.hour)}:'
        '${twoDigits(date.minute)}:00';
  }

  String _formatDate(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${twoDigits(date.day)}/'
        '${twoDigits(date.month)}/'
        '${date.year}';
  }

  String _formatTime(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }

  String _subjectName(int? subjectId) {
    if (subjectId == null) return 'No subject';

    for (final subject in _subjects) {
      if (subject.id == subjectId) return subject.name;
    }

    return 'No subject';
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'HIGH':
        return Colors.red;
      case 'LOW':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  String _priorityLabel(String priority) {
    switch (priority) {
      case 'HIGH':
        return 'High';
      case 'LOW':
        return 'Low';
      default:
        return 'Medium';
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'IN_PROGRESS':
        return 'In Progress';
      case 'DONE':
        return 'Done';
      default:
        return 'Pending';
    }
  }

  Widget _buildStatusFilters() {
    const filters = [
      ('ALL', 'All'),
      ('PENDING', 'Pending'),
      ('IN_PROGRESS', 'In Progress'),
      ('DONE', 'Done'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final selected = _statusFilter == filter.$1;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter.$2),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _statusFilter = filter.$1;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPriorityFilters() {
    const filters = [
      ('ALL', 'All'),
      ('LOW', 'Low'),
      ('MEDIUM', 'Medium'),
      ('HIGH', 'High'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final selected = _priorityFilter == filter.$1;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter.$2),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _priorityFilter = filter.$1;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTaskCard(StudyTask task) {
    final theme = Theme.of(context);
    final priorityColor = _priorityColor(task.priority);
    final dueDate = task.parsedDueDate;

    final isOverdue = dueDate != null &&
        dueDate.isBefore(DateTime.now()) &&
        task.status != 'DONE';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  enabled: !_isSaving,
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditDialog(task);
                    } else if (value == 'delete') {
                      _deleteTask(task);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined),
                          SizedBox(width: 10),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red),
                          SizedBox(width: 10),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (task.description != null &&
                task.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                task.description!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!_isSubjectScreen)
                  _TaskTag(
                    icon: Icons.menu_book_outlined,
                    label: _subjectName(task.subjectId),
                  ),
                _TaskTag(
                  icon: Icons.flag_outlined,
                  label: _priorityLabel(task.priority),
                  color: priorityColor,
                ),
                _TaskTag(
                  icon: Icons.circle_outlined,
                  label: _statusLabel(task.status),
                  color: task.status == 'DONE' ? Colors.green : null,
                ),
                if (dueDate != null)
                  _TaskTag(
                    icon: Icons.calendar_today_outlined,
                    label: _formatDate(dueDate),
                  ),
                if (dueDate != null)
                  _TaskTag(
                    icon: Icons.access_time,
                    label: _formatTime(dueDate),
                    color: isOverdue ? Colors.red : null,
                  ),
                if (isOverdue)
                  const _TaskTag(
                    icon: Icons.warning_amber_rounded,
                    label: 'Overdue',
                    color: Colors.red,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading && _tasks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final tasks = _filteredTasks;

    if (tasks.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadData(showLoader: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 100),
          children: [
            const Icon(
              Icons.task_alt,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                _tasks.isEmpty
                    ? 'No tasks yet'
                    : 'No matching tasks',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _tasks.isEmpty
                    ? 'Tap + to create your first task.'
                    : 'Try changing your search or filters.',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(showLoader: false),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: tasks.length,
        itemBuilder: (context, index) => _buildTaskCard(tasks[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _isSaving ? null : _showCreateDialog,
        tooltip: 'Create task',
        child: _isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isSubjectScreen)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  widget.subject!.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search tasks...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close),
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Status',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildStatusFilters(),
                  const SizedBox(height: 12),
                  Text(
                    'Priority',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPriorityFilters(),
                  const SizedBox(height: 8),
                  Text(
                    '${_filteredTasks.length} '
                    '${_filteredTasks.length == 1 ? 'task' : 'tasks'}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }
}

class _TaskTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _TaskTag({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: effectiveColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: effectiveColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskFormData {
  final int? subjectId;
  final String title;
  final String description;
  final DateTime? dueDate;
  final String priority;
  final String status;

  const _TaskFormData({
    required this.subjectId,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.priority,
    required this.status,
  });
}

class _TaskFormDialog extends StatefulWidget {
  final List<Subject> subjects;
  final StudyTask? task;
  final int? fixedSubjectId;

  const _TaskFormDialog({
    required this.subjects,
    this.task,
    this.fixedSubjectId,
  });

  @override
  State<_TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<_TaskFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  late int _selectedSubjectId;
  late String _priority;
  late String _status;
  DateTime? _dueDate;

  bool get _isEditing => widget.task != null;

  static const List<String> _priorities = [
    'LOW',
    'MEDIUM',
    'HIGH',
  ];

  static const List<String> _statuses = [
    'PENDING',
    'IN_PROGRESS',
    'DONE',
  ];

  @override
  void initState() {
    super.initState();

    final task = widget.task;

    _titleController = TextEditingController(
      text: task?.title ?? '',
    );

    _descriptionController = TextEditingController(
      text: task?.description ?? '',
    );

    _selectedSubjectId =
        widget.fixedSubjectId ?? task?.subjectId ?? 0;

    _priority = _priorities.contains(task?.priority)
        ? task!.priority
        : 'MEDIUM';

    _status = _statuses.contains(task?.status)
        ? task!.status
        : 'PENDING';

    _dueDate = task?.parsedDueDate;

    if (_selectedSubjectId != 0 &&
        !widget.subjects.any(
          (subject) => subject.id == _selectedSubjectId,
        )) {
      _selectedSubjectId = 0;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );

    if (selected == null || !mounted) return;

    setState(() {
      final current = _dueDate ?? DateTime.now();

      _dueDate = DateTime(
        selected.year,
        selected.month,
        selected.day,
        current.hour,
        current.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    if (_dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose a deadline date first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueDate!),
    );

    if (selected == null || !mounted) return;

    setState(() {
      _dueDate = DateTime(
        _dueDate!.year,
        _dueDate!.month,
        _dueDate!.day,
        selected.hour,
        selected.minute,
      );
    });
  }

  String _formatDate(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${twoDigits(date.day)}/'
        '${twoDigits(date.month)}/'
        '${date.year}';
  }

  String _formatTime(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }

  String _statusName(String status) {
    switch (status) {
      case 'IN_PROGRESS':
        return 'In Progress';
      case 'DONE':
        return 'Done';
      default:
        return 'Pending';
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      _TaskFormData(
        subjectId: widget.fixedSubjectId ??
            (_selectedSubjectId == 0 ? null : _selectedSubjectId),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        dueDate: _dueDate,
        priority: _priority,
        status: _status,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Task' : 'Create Task'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Task title',
                  hintText: 'e.g. Prepare project presentation',
                  prefixIcon: Icon(Icons.task_alt),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a task title.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Add details (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              if (widget.fixedSubjectId == null)
                DropdownButtonFormField<int>(
                  initialValue: _selectedSubjectId,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    prefixIcon: Icon(Icons.menu_book_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 0,
                      child: Text('No subject'),
                    ),
                    ...widget.subjects.map(
                      (subject) => DropdownMenuItem(
                        value: subject.id,
                        child: Text(subject.name),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedSubjectId = value ?? 0;
                    });
                  },
                )
              else
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    prefixIcon: Icon(Icons.menu_book_outlined),
                  ),
                  child: Text(
                    widget.subjects
                        .firstWhere(
                          (s) => s.id == widget.fixedSubjectId,
                        )
                        .name,
                  ),
                ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                items: _priorities.map((priority) {
                  return DropdownMenuItem(
                    value: priority,
                    child: Text(
                      '${priority[0]}${priority.substring(1).toLowerCase()}',
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _priority = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(Icons.check_circle_outline),
                ),
                items: _statuses.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(_statusName(status)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _status = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Deadline',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        _dueDate == null
                            ? 'Choose date'
                            : _formatDate(_dueDate!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _dueDate == null ? null : _pickTime,
                      icon: const Icon(Icons.access_time),
                      label: Text(
                        _dueDate == null
                            ? 'Choose time'
                            : _formatTime(_dueDate!),
                      ),
                    ),
                  ),
                  if (_dueDate != null)
                    IconButton(
                      tooltip: 'Clear deadline',
                      onPressed: () {
                        setState(() {
                          _dueDate = null;
                        });
                      },
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(_isEditing ? 'Save changes' : 'Create'),
        ),
      ],
    );
  }
}
