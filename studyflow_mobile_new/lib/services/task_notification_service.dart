
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class TaskNotificationService {
  TaskNotificationService._();

  static final TaskNotificationService instance =
      TaskNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'task_deadline_reminders';
  static const String _channelName = 'Task deadline reminders';

  static const Duration _firstReminderOffset = Duration(hours: 24);
  static const Duration _secondReminderOffset = Duration(hours: 1);

  bool _initialized = false;
  bool _exactAlarmsAllowed = false;

  Future<void>? _initializationFuture;

  Future<void> initialize() async {
    if (_initialized) return;

    final existingInitialization = _initializationFuture;

    if (existingInitialization != null) {
      await existingInitialization;
      return;
    }

    final initialization = _initializeInternal();
    _initializationFuture = initialization;

    try {
      await initialization;
      _initialized = true;
    } finally {
      _initializationFuture = null;
    }
  }

  Future<void> _initializeInternal() async {
    // Load the timezone database.
    tz_data.initializeTimeZones();

    // Read the device timezone.
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    final identifier = timezoneInfo.identifier.trim();

    // Use the device timezone if it exists in the database.
    // GMT and UTC are mapped to the IANA Etc/UTC identifier.
    try {
      final normalizedIdentifier =
          identifier.isEmpty ||
                  identifier.toUpperCase() == 'GMT' ||
                  identifier.toUpperCase() == 'UTC'
              ? 'Etc/UTC'
              : identifier;

      tz.setLocalLocation(
        tz.getLocation(normalizedIdentifier),
      );
    } catch (_) {
      // Safe fallback if the device timezone is not in the database.
      tz.setLocalLocation(
        tz.getLocation('Etc/UTC'),
      );
    }

    // Initialize notifications.
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );

    await _plugin.initialize(
      settings: initializationSettings,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();

      _exactAlarmsAllowed =
          await androidPlugin.canScheduleExactNotifications() ?? false;

      if (!_exactAlarmsAllowed) {
        await androidPlugin.requestExactAlarmsPermission();

        _exactAlarmsAllowed =
            await androidPlugin.canScheduleExactNotifications() ?? false;
      }
    }
  }

  Future<void> scheduleTaskReminders({
    required String taskId,
    required String taskTitle,
    required DateTime deadline,
  }) async {
    await initialize();

    if (taskId.trim().isEmpty) {
      throw ArgumentError.value(
        taskId,
        'taskId',
        'Cannot be empty.',
      );
    }

    await cancelTaskReminders(taskId);

    final localDeadline = tz.TZDateTime.from(
      deadline,
      tz.local,
    );

    final now = tz.TZDateTime.now(tz.local);

    final reminders = <_TaskReminder>[
      _TaskReminder(
        id: _notificationId(taskId, 1),
        scheduledDate: localDeadline.subtract(_firstReminderOffset),
        title: 'Task due tomorrow',
        body: '"$taskTitle" is due in 24 hours.',
      ),
      _TaskReminder(
        id: _notificationId(taskId, 2),
        scheduledDate: localDeadline.subtract(_secondReminderOffset),
        title: 'Task due in 1 hour',
        body: '"$taskTitle" is due in 1 hour.',
      ),
    ];

    for (final reminder in reminders) {
      if (!reminder.scheduledDate.isAfter(now)) {
        continue;
      }

      await _plugin.zonedSchedule(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: reminder.scheduledDate,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Reminders before task deadlines',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: _exactAlarmsAllowed
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: taskId,
      );
    }
  }

  Future<void> cancelTaskReminders(String taskId) async {
    await initialize();

    await _plugin.cancel(
      id: _notificationId(taskId, 1),
    );

    await _plugin.cancel(
      id: _notificationId(taskId, 2),
    );
  }

  Future<void> cancelAllReminders() async {
    await initialize();
    await _plugin.cancelAll();
  }

  Future<List<PendingNotificationRequest>> getPendingReminders() async {
    await initialize();
    return _plugin.pendingNotificationRequests();
  }

  int _notificationId(String taskId, int reminderNumber) {
    var hash = 0x811C9DC5;

    for (final codeUnit in taskId.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }

    final base = hash % 1000000000;

    return (base * 2) + reminderNumber;
  }
}

class _TaskReminder {
  final int id;
  final tz.TZDateTime scheduledDate;
  final String title;
  final String body;

  const _TaskReminder({
    required this.id,
    required this.scheduledDate,
    required this.title,
    required this.body,
  });
}
