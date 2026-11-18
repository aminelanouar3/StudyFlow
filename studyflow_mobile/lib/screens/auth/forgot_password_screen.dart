
import 'package:flutter/material.dart';

import '../../services/authentication_service.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _step = 0;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String get _email => _emailController.text.trim();
  String get _code => _codeController.text.trim();

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _requestCode() async {
    if (_email.isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
            .hasMatch(_email)) {
      _showMessage('Please enter a valid email address.');
      return;
    }

    setState(() => _loading = true);

    try {
      final response =
          await AuthenticationService.forgotPassword(_email);

      if (!mounted) return;

      if (response.success) {
        setState(() => _step = 1);
        _showMessage(response.message);
      } else {
        _showMessage(response.message);
      }
    } catch (e) {
      _showMessage('Could not request a reset code: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _verifyCode() async {
    if (_code.isEmpty) {
      _showMessage('Please enter the reset code.');
      return;
    }

    setState(() => _loading = true);

    try {
      final response =
          await AuthenticationService.verifyResetCode(
        _email,
        _code,
      );

      if (!mounted) return;

      if (response.success) {
        setState(() => _step = 2);
        _showMessage('Code verified successfully.');
      } else {
        _showMessage(response.message);
      }
    } catch (e) {
      _showMessage('Code verification failed: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (password.isEmpty || confirmPassword.isEmpty) {
      _showMessage('Please fill in both password fields.');
      return;
    }

    if (password != confirmPassword) {
      _showMessage('Passwords do not match.');
      return;
    }

    setState(() => _loading = true);

    try {
      final response =
          await AuthenticationService.resetPassword(
        _email,
        _code,
        password,
      );

      if (!mounted) return;

      if (response.success) {
        _showMessage('Password reset successfully.');

        await Future.delayed(
          const Duration(milliseconds: 500),
        );

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const LoginScreen(),
          ),
          (route) => false,
        );
      } else {
        _showMessage(response.message);
      }
    } catch (e) {
      _showMessage('Password reset failed: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Enter your email address. We will send you a password reset code.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email address',
            prefixIcon: Icon(Icons.email_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _loading ? null : _requestCode,
          child: _loading
              ? const CircularProgressIndicator()
              : const Text('Send reset code'),
        ),
      ],
    );
  }

  Widget _buildCodeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter the reset code sent to $_email',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            labelText: 'Reset code',
            border: OutlineInputBorder(),
            counterText: '',
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _loading ? null : _verifyCode,
          child: _loading
              ? const CircularProgressIndicator()
              : const Text('Verify code'),
        ),
        TextButton(
          onPressed: _loading ? null : _requestCode,
          child: const Text('Resend reset code'),
        ),
        TextButton(
          onPressed: _loading
              ? null
              : () => setState(() => _step = 0),
          child: const Text('Change email address'),
        ),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Choose a new password for your account.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'New password',
            prefixIcon: const Icon(Icons.lock_outline),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            labelText: 'Confirm new password',
            prefixIcon: const Icon(Icons.lock_outline),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword =
                      !_obscureConfirmPassword;
                });
              },
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _loading ? null : _resetPassword,
          child: _loading
              ? const CircularProgressIndicator()
              : const Text('Reset password'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      'Forgot password?',
      'Verify reset code',
      'Create new password',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Password recovery'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.lock_reset,
                  size: 76,
                ),
                const SizedBox(height: 24),
                Text(
                  titles[_step],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (_step == 0) _buildEmailStep(),
                if (_step == 1) _buildCodeStep(),
                if (_step == 2) _buildPasswordStep(),
                const SizedBox(height: 20),
                if (_step == 0)
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('Back to login'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
