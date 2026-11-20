
import 'package:flutter/material.dart';

import '../../models/subject.dart';
import '../tasks/task_list_screen.dart';

class SubjectTasksScreen extends StatelessWidget {
  final Subject subject;

  const SubjectTasksScreen({
    super.key,
    required this.subject,
  });

  @override
  Widget build(BuildContext context) {
    return TaskListPage(
      title: '${subject.name} Tasks',
      subjectId: subject.id,
    );
  }
}
