import 'package:flutter/material.dart';

import '../../models/subject.dart';
import '../../services/subject_service.dart';
import 'subject_tasks_screen.dart';

class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> {
  List<Subject> _subjects = [];
  bool _isLoading = true;
  String? _error;

  static const Color _primary = Color(0xFF6C63FF);

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await SubjectService.getSubjects();

    if (!mounted) return;

    setState(() {
      _isLoading = false;

      if (result.success) {
        _subjects = result.subjects;
      } else {
        _error = result.message;
      }
    });
  }

  Color _subjectColor(String value) {
    try {
      final normalized = value.replaceAll('#', '');
      return Color(int.parse('FF$normalized', radix: 16));
    } catch (_) {
      return _primary;
    }
  }

  Future<void> _openSubjectForm({Subject? subject}) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: subject?.name ?? '');
    final descriptionController = TextEditingController(
      text: subject?.description ?? '',
    );
    final colorController = TextEditingController(
      text: subject?.color ?? '#6C63FF',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(subject == null ? 'Add Subject' : 'Edit Subject'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Subject name',
                          prefixIcon: Icon(Icons.book_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter a subject name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          prefixIcon: Icon(Icons.description_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: colorController,
                        decoration: const InputDecoration(
                          labelText: 'Color (HEX)',
                          hintText: '#6C63FF',
                          prefixIcon: Icon(Icons.palette_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final color = value?.trim() ?? '';
                          if (!RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(color)) {
                            return 'Enter a valid HEX color';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }

                          setDialogState(() => saving = true);

                          final color = colorController.text.trim();
                          final normalizedColor = color.startsWith('#')
                              ? color
                              : '#$color';

                          final operation = subject == null
                              ? await SubjectService.createSubject(
                                  name: nameController.text.trim(),
                                  description: descriptionController.text
                                      .trim(),
                                  color: normalizedColor,
                                )
                              : await SubjectService.updateSubject(
                                  subjectId: subject.id,
                                  name: nameController.text.trim(),
                                  description: descriptionController.text
                                      .trim(),
                                  color: normalizedColor,
                                );

                          if (!dialogContext.mounted) return;

                          if (operation.success) {
                            Navigator.pop(dialogContext, true);
                          } else {
                            setDialogState(() => saving = false);

                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(content: Text(operation.message)),
                            );
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(subject == null ? 'Create' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
      descriptionController.dispose();
    });

    if (result == true && mounted) {
      await _loadSubjects();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            subject == null
                ? 'Subject created successfully.'
                : 'Subject updated successfully.',
          ),
        ),
      );
    }
  }

  Future<void> _deleteSubject(Subject subject) async {
    bool deleteTasks = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Delete Subject'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What should happen to the tasks associated with '
                    '"${subject.name}"?',
                  ),
                  const SizedBox(height: 15),

                  InkWell(
                    onTap: () {
                      setDialogState(() => deleteTasks = true);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            deleteTasks
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: deleteTasks
                                ? const Color(0xFF6C63FF)
                                : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Delete subject and its tasks',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  'All associated tasks will also be deleted.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  InkWell(
                    onTap: () {
                      setDialogState(() => deleteTasks = false);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            !deleteTasks
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: !deleteTasks
                                ? const Color(0xFF6C63FF)
                                : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Preserve associated tasks',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  'Tasks will remain without a subject.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () {
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final result = await SubjectService.deleteSubject(
      subjectId: subject.id,
      deleteTasks: deleteTasks,
    );

    if (!mounted) return;

    if (result.success) {
      await _loadSubjects();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subject deleted successfully.')),
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  Widget _buildSubjectCard(Subject subject) {
    final color = _subjectColor(subject.color);

    return Card(
      margin: const EdgeInsets.only(bottom: 13),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SubjectTasksScreen(subject: subject),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.menu_book_rounded, color: color, size: 27),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subject.description.isEmpty
                          ? 'No description'
                          : subject.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _openSubjectForm(subject: subject);
                  } else if (value == 'delete') {
                    _deleteSubject(subject);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline, color: Colors.red),
                      title: Text('Delete'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Subjects'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _loadSubjects,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 55,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 15),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 15),
                    FilledButton.icon(
                      onPressed: _loadSubjects,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : _subjects.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 75,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No subjects yet',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your first subject to organize '
                      'your studies.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadSubjects,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Text(
                    '${_subjects.length} '
                    '${_subjects.length == 1 ? 'subject' : 'subjects'}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 15),
                  ..._subjects.map(_buildSubjectCard),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSubjectForm(),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Subject'),
      ),
    );
  }
}
