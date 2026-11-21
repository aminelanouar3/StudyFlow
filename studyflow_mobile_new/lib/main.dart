
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'services/task_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await TaskNotificationService.instance.initialize();

  runApp(const StudyFlowApp());
}
