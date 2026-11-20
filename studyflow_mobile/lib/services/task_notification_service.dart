
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/task.dart';

class TaskNotificationService {
  TaskNotificationService._();

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static const String _channelId = 'studyflow_task_reminders';

  static Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Tunis'));

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );

    await _notifications.initialize(initializationSettings);

    final android = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await android?.requestNotificationsPermission();

    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    _initialized = true;
  }

  static int _id(int taskId, int reminder) =>
      taskId * 10 + reminder;

  static Future<void> cancelTaskReminders(int taskId) async {
    await _notifications.cancel(_id(taskId, 1));
    await _notifications.cancel(_id(taskId, 2));
  }

  static Future<void> scheduleTaskReminders(Task task) async {
    await initialize();
    await cancelTaskReminders(task.id);

    if (task.status == 'DONE') return;

    if (task.dueDate == null || task.dueDate!.isEmpty) return;

    final dueDate = DateTime.tryParse(task.dueDate!);
    if (dueDate == null) return;

    final localDueDate = tz.TZDateTime.from(dueDate, tz.local);
    final now = tz.TZDateTime.now(tz.local);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'StudyFlow task reminders',
        channelDescription: 'Upcoming task deadlines',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final reminders = [
      (
        id: _id(task.id, 1),
        date: localDueDate.subtract(const Duration(hours: 24)),
        message: 'Your task is due in 24 hours.',
      ),
      (
        id: _id(task.id, 2),
        date: localDueDate.subtract(const Duration(hours: 1)),
        message: 'Your task is due in one hour.',
      ),
    ];

    for (final reminder in reminders) {
      if (!reminder.date.isAfter(now)) continue;

      await _notifications.zonedSchedule(
        reminder.id,
        'StudyFlow reminder',
        '${reminder.message} ${task.title}',
        reminder.date,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: task.id.toString(),
      );
    }
  }
}
