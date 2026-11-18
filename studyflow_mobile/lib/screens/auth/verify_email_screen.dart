
import 'package:flutter/material.dart';

import '../../services/authentication_service.dart';
import 'login_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;

  const VerifyEmailScreen({
    super.key,
    required this.email,
  });

  @override
  State<VerifyEmailScreen> createState() =>
      _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final TextEditingController _codeController =
      TextEditingController();

  bool _loading = false;
  bool _resending = false;

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _verifyEmail() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      _showMessage('Please enter the verification code.');
      return;
    }

    setState(() => _loading = true);

    try {
      final response =
          await AuthenticationService.verifyEmail(
        widget.email,
        code,
      );

      if (!mounted) return;

      if (response.success) {
        _showMessage('Email verified successfully.');

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
      _showMessage('Verification failed: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resendCode() async {
    setState(() => _resending = true);

    try {
      final response =
          await AuthenticationService.resendVerificationCode(
        widget.email,
      );

      if (!mounted) return;

      _showMessage(response.message);
    } catch (e) {
      _showMessage('Unable to resend the code: $e');
    } finally {
      if (mounted) {
        setState(() => _resending = false);
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify email'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.mark_email_read_outlined,
                  size: 76,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Verify your email address',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'We sent a verification code to:',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  widget.email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Verification code',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loading ? null : _verifyEmail,
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Verify email'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _resending ? null : _resendCode,
                  child: _resending
                      ? const CircularProgressIndicator()
                      : const Text(
                          'Resend verification code',
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
