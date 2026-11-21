
import 'package:xml/xml.dart' as xml;

class DashboardTask {
  final int id;
  final String? title;
  final String? description;
  final String? dueDate;
  final String? priority;
  final String? status;
  final String? createdAt;

  const DashboardTask({
    required this.id,
    this.title,
    this.description,
    this.dueDate,
    this.priority,
    this.status,
    this.createdAt,
  });

  DateTime? get parsedDueDate {
    if (dueDate == null || dueDate!.isEmpty) return null;
    return DateTime.tryParse(dueDate!);
  }
}

class DashboardData {
  final int totalSubjects;
  final int totalTasks;
  final int pendingTasks;
  final int inProgressTasks;
  final int completedTasks;
  final int overdueTasks;
  final int upcomingTasks;
  final double progressPercentage;
  final List<DashboardTask> tasks;

  const DashboardData({
    required this.totalSubjects,
    required this.totalTasks,
    required this.pendingTasks,
    required this.inProgressTasks,
    required this.completedTasks,
    required this.overdueTasks,
    required this.upcomingTasks,
    required this.progressPercentage,
    required this.tasks,
  });

  factory DashboardData.fromXmlReturn(xml.XmlElement element) {
    String value(xml.XmlElement parent, String name) {
      for (final child in parent.childElements) {
        if (child.name.local == name) {
          return child.innerText.trim();
        }
      }
      return '';
    }

    int number(String name) {
      return int.tryParse(value(element, name)) ?? 0;
    }

    final tasks = element.childElements
        .where((child) => child.name.local == 'task')
        .map((task) {
          final id = int.tryParse(value(task, 'id')) ?? 0;

          return DashboardTask(
            id: id,
            title: value(task, 'title'),
            description: value(task, 'description'),
            dueDate: value(task, 'dueDate'),
            priority: value(task, 'priority'),
            status: value(task, 'status'),
            createdAt: value(task, 'createdAt'),
          );
        })
        .toList();

    return DashboardData(
      totalSubjects: number('totalSubjects'),
      totalTasks: number('totalTasks'),
      pendingTasks: number('pendingTasks'),
      inProgressTasks: number('inProgressTasks'),
      completedTasks: number('completedTasks'),
      overdueTasks: number('overdueTasks'),
      upcomingTasks: number('upcomingTasks'),
      progressPercentage:
          double.tryParse(value(element, 'progressPercentage')) ?? 0,
      tasks: tasks,
    );
  }
}
