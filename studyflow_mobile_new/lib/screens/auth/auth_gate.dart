
import 'package:flutter/material.dart';

import '../../services/authentication_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_loader.dart';
import '../../theme/app_colors.dart';
import 'login_screen.dart';
import '../home/home_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  String? _errorMessage;
  Widget _destination = const LoginScreen();

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final token = await SessionService.getToken();

      if (token == null || token.isEmpty) {
        _destination = const LoginScreen();
      } else {
        final response =
            await AuthenticationService.getProfile(token: token);

        if (response.success) {
          _destination = const HomeScreen();
        } else {
          await SessionService.clearSession();
          _destination = const LoginScreen();
        }
      }
    } catch (e) {
      // Keep the saved token if the server is unavailable.
      _errorMessage =
          'Unable to connect to the server. Please try again.';
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    await SessionService.clearSession();

    if (!mounted) return;

    setState(() {
      _errorMessage = null;
      _destination = const LoginScreen();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: AppLoader(message: 'Restoring your session...'),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(
                AppDimensions.screenPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 56,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Connection unavailable',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    text: 'Try again',
                    onPressed: _restoreSession,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _signOut,
                    child: const Text('Sign in with another account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return _destination;
  }
}
