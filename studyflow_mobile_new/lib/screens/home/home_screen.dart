
import 'package:flutter/material.dart';

import '../../models/dashboard_data.dart';
import '../../models/subject.dart';
import '../../services/authentication_service.dart';
import '../../services/dashboard_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/app_bottom_navigation_bar.dart';
import '../auth/login_screen.dart';
import '../subjects/subjects_screen.dart';
import '../tasks/tasks_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isLoggingOut = false;

  Subject? _selectedSubject;

  late final List<Widget> _screens = [
    const _HomeContent(),
    SubjectsScreen(
      onSubjectSelected: _openSubjectTasks,
    ),
    const TasksScreen(),
    const ProfileScreen(),
  ];

  final List<String> _titles = const [
    'StudyFlow',
    'My Subjects',
    'My Tasks',
    'My Profile',
  ];

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
      _selectedSubject = null;
    });
  }

  void _openSubjectTasks(Subject subject) {
    setState(() {
      _selectedSubject = subject;
    });
  }

  void _closeSubjectTasks() {
    setState(() {
      _selectedSubject = null;
      _currentIndex = 1;
    });
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;

    setState(() => _isLoggingOut = true);

    try {
      final token = await SessionService.getToken();

      await SessionService.clearSession();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
        (route) => false,
      );

      if (token != null && token.isNotEmpty) {
        AuthenticationService.logout(token: token).then(
          (_) {},
          onError: (Object error) {
            debugPrint('Backend logout failed: $error');
          },
        );
      }
    } catch (e) {
      debugPrint('Local logout failed: $e');

      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isViewingSubjectTasks = _selectedSubject != null;

    return Scaffold(
      appBar: AppBar(
        leading: isViewingSubjectTasks
            ? IconButton(
                tooltip: 'Back to subjects',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _closeSubjectTasks,
              )
            : null,
        title: Text(
          isViewingSubjectTasks
              ? _selectedSubject!.name
              : _titles[_currentIndex],
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: _isLoggingOut ? null : _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isViewingSubjectTasks
          ? TasksScreen(subject: _selectedSubject!)
          : IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
      bottomNavigationBar: AppBottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
      ),
    );
  }
}

class _HomeContent extends StatefulWidget {
  const _HomeContent();

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  DashboardData? _dashboard;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await SessionService.getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Your session has expired. Please sign in again.');
      }

      final result = await DashboardService.getDashboard(
        token: token,
      );

      if (!mounted) return;

      setState(() {
        _dashboard = result;
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _dashboard == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null && _dashboard == null) {
      return _buildError();
    }

    if (_dashboard == null) {
      return const Center(
        child: Text('No dashboard data available.'),
      );
    }

    return _buildDashboard(_dashboard!);
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadDashboard,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(DashboardData data) {
    final progress = (data.progressPercentage / 100)
        .clamp(0.0, 1.0)
        .toDouble();

    final tasks = data.tasks.take(5).toList();

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppDimensions.screenPadding),
        children: [
          Text(
            'Your study overview',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Keep track of your learning progress.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),

          // General statistics
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Subjects',
                  value: data.totalSubjects,
                  icon: Icons.menu_book_rounded,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Total tasks',
                  value: data.totalTasks,
                  icon: Icons.assignment_rounded,
                  color: Colors.deepPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Task statuses
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Pending',
                  value: data.pendingTasks,
                  icon: Icons.pending_actions_rounded,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'In progress',
                  value: data.inProgressTasks,
                  icon: Icons.autorenew_rounded,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Completed',
                  value: data.completedTasks,
                  icon: Icons.check_circle_outline_rounded,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Progress
          Text(
            'Overall progress',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Completed tasks'),
                      Text(
                        '${data.progressPercentage.toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade200,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${data.completedTasks} of ${data.totalTasks} tasks completed',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Deadlines overview
          Text(
            'Deadlines overview',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Overdue',
                  value: data.overdueTasks,
                  icon: Icons.warning_amber_rounded,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Upcoming',
                  value: data.upcomingTasks,
                  icon: Icons.event_available_rounded,
                  color: Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Upcoming tasks
          Text(
            'Upcoming tasks',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),

          if (tasks.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text('No upcoming tasks.'),
                ),
              ),
            )
          else
            ...tasks.map(
              (task) => _DashboardTaskCard(task: task),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 10),
            Text(
              value.toString(),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardTaskCard extends StatelessWidget {
  final DashboardTask task;

  const _DashboardTaskCard({
    required this.task,
  });

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final rawDueDate = task.dueDate;

    final dueDate = rawDueDate == null || rawDueDate.isEmpty
        ? null
        : DateTime.tryParse(rawDueDate.replaceFirst(' ', 'T'));

    final isOverdue = dueDate != null &&
        dueDate.isBefore(DateTime.now()) &&
        (task.status ?? '').toUpperCase() != 'DONE';

    final status = (task.status ?? 'UNKNOWN').replaceAll('_', ' ');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isOverdue
              ? Colors.red.withValues(alpha: 0.10)
              : null,
          child: Icon(
            isOverdue
                ? Icons.warning_amber_rounded
                : Icons.assignment_outlined,
            color: isOverdue ? Colors.red : null,
          ),
        ),
        title: Text(
          task.title ?? 'Untitled task',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dueDate != null) ...[
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(_formatDate(dueDate)),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.access_time_rounded,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(_formatTime(dueDate)),
                ],
              ),
            ],
            const SizedBox(height: 5),
            Text(
              '${task.priority ?? 'No priority'} • $status',
            ),
            if (isOverdue) ...[
              const SizedBox(height: 5),
              const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: Colors.red,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Overdue',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
