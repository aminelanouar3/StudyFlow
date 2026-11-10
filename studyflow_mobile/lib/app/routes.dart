
import 'package:flutter/material.dart';

import '../models/auth_response.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/home/home_screen.dart';

class AppRoutes {
  static const String login = '/';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String home = '/home';

  static Map<String, WidgetBuilder> get routes => {
    login: (context) => const LoginScreen(),
    register: (context) => const RegisterScreen(),
    forgotPassword: (context) => const ForgotPasswordScreen(),
    home: (context) {
      final user =
          ModalRoute.of(context)!.settings.arguments as AuthResponse;

      return HomeScreen(user: user);
    },
  };
}
