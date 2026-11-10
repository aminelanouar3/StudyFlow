
import 'package:flutter/material.dart';

import '../models/auth_response.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/home/home_screen.dart';
import '../services/session_manager.dart';
import 'routes.dart';

class StudyFlowApp extends StatelessWidget {
  const StudyFlowApp({super.key});

  Route<dynamic> _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        );

      case AppRoutes.register:
        return MaterialPageRoute(
          builder: (_) => const RegisterScreen(),
        );

      case AppRoutes.forgotPassword:
        return MaterialPageRoute(
          builder: (_) => const ForgotPasswordScreen(),
        );

      case AppRoutes.home:
        final user = settings.arguments;

        if (user is AuthResponse) {
          return MaterialPageRoute(
            builder: (_) => HomeScreen(user: user),
          );
        }

        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StudyFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F8FC),
        fontFamily: 'Roboto',
      ),

      // SessionGate decides whether to show Login or Home.
      home: const SessionGate(),

      // Named navigation is handled here.
      // No routes table containing "/" is necessary.
      onGenerateRoute: _generateRoute,
    );
  }
}

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final Future<AuthResponse?> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionFuture = SessionManager.restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthResponse?>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = snapshot.data;

        if (user != null && user.success) {
          return HomeScreen(user: user);
        }

        return const LoginScreen();
      },
    );
  }
}
