
import 'package:flutter/material.dart';

import '../../models/auth_response.dart';
import '../../services/authentication_service.dart';
import '../../services/session_manager.dart';
import '../../app/routes.dart';

class HomeScreen extends StatelessWidget {
  final AuthResponse user;

  const HomeScreen({
    super.key,
    required this.user,
  });

  Future<void> _logout(BuildContext context) async {
    final token = await SessionManager.getToken();

    if (token != null) {
      try {
        await AuthenticationService.logout(token: token);
      } catch (_) {
        // The local session will still be cleared.
      }
    }

    await SessionManager.clearSession();

    if (!context.mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('StudyFlow'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.school_rounded,
                size: 70,
                color: Color(0xFF6C63FF),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome, ${user.fullName ?? 'Student'}!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(user.email ?? ''),
              const SizedBox(height: 20),
              const Text('Authentication successful!'),
            ],
          ),
        ),
      ),
    );
  }
}
