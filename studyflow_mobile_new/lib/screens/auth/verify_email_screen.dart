
import 'package:flutter/material.dart';

import '../../services/authentication_service.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  bool _isLoading = false;
  bool _isResending = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await AuthenticationService.verifyEmail(
        email: widget.email,
        code: _codeController.text.trim(),
      );

      if (!mounted) return;

      if (!response.success) {
        _showMessage(
          response.message ?? 'Invalid verification code.',
        );
        return;
      }

      _showMessage(
        response.message ?? 'Email verified. You can now sign in.',
      );

      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        _showMessage(
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendCode() async {
    setState(() => _isResending = true);

    try {
      final response =
          await AuthenticationService.resendVerificationCode(
        email: widget.email,
      );

      if (!mounted) return;

      _showMessage(
        response.message ??
            (response.success
                ? 'A new code has been sent.'
                : 'Unable to resend the code.'),
      );
    } catch (e) {
      if (mounted) {
        _showMessage(
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify email')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(
              AppDimensions.screenPadding,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.mark_email_read_outlined,
                      size: 64,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Check your email',
                      style: Theme.of(context)
                          .textTheme
                          .headlineLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'We sent a verification code to ${widget.email}. Enter it below to verify your account.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 28),

                    AppTextField(
                      controller: _codeController,
                      label: 'Verification code',
                      hint: 'Enter the code',
                      prefixIcon: Icons.pin_outlined,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _verify(),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter the verification code.';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    AppButton(
                      text: 'Verify email',
                      isLoading: _isLoading,
                      onPressed: _verify,
                    ),

                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: (_isLoading || _isResending)
                          ? null
                          : _resendCode,
                      child: _isResending
                          ? const CircularProgressIndicator()
                          : const Text('Resend verification code'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
