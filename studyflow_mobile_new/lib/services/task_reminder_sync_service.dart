
import '../models/task.dart';
import 'task_notification_service.dart';

/// Rebuilds local task reminders from the backend task list.
class TaskReminderSyncService {
  TaskReminderSyncService._();

  static final TaskNotificationService _notifications =
      TaskNotificationService.instance;

  /// Synchronizes local reminders for every supplied task.
  ///
  /// A notification failure must never prevent the application
  /// from loading its tasks.
  static Future<void> synchronize(List<StudyTask> tasks) async {
    try {
      await _notifications.initialize();
    } catch (_) {
      return;
    }

    for (final task in tasks) {
      try {
        final taskId = task.id.toString();
        final status = task.status.trim().toUpperCase();

        // Completed tasks must not have deadline reminders.
        if (status == 'DONE' || status == 'COMPLETED') {
          await _notifications.cancelTaskReminders(taskId);
          continue;
        }

        final rawDeadline = task.dueDate?.trim();

        // Tasks without a deadline must not have reminders.
        if (rawDeadline == null || rawDeadline.isEmpty) {
          await _notifications.cancelTaskReminders(taskId);
          continue;
        }

        // Accept both:
        // 2026-11-21 19:00:00
        // 2026-11-21T19:00:00
        final normalizedDeadline = rawDeadline.contains('T')
            ? rawDeadline
            : rawDeadline.replaceFirst(' ', 'T');

        final deadline = DateTime.tryParse(normalizedDeadline);

        // Invalid deadlines must not leave outdated reminders.
        if (deadline == null) {
          await _notifications.cancelTaskReminders(taskId);
          continue;
        }

        // Schedule the 24-hour and 1-hour reminders.
        // The notification service skips reminder times in the past.
        await _notifications.scheduleTaskReminders(
          taskId: taskId,
          taskTitle: task.title,
          deadline: deadline,
        );
      } catch (_) {
        // A failure for one task must not stop synchronization
        // of the remaining tasks.
        continue;
      }
    }
  }
}
