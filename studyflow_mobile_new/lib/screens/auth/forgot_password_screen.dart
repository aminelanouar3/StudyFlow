
import 'package:flutter/material.dart';

import '../../services/authentication_service.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _step = 0;
  bool _isLoading = false;
  bool _isResending = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;

    await _performRequest(() async {
      final response =
          await AuthenticationService.forgotPassword(
        email: _emailController.text.trim(),
      );

      if (!response.success) {
        throw Exception(
          response.message ?? 'Unable to send reset code.',
        );
      }

      setState(() => _step = 1);

      _showMessage(
        response.message ?? 'Password reset code sent.',
      );
    });
  }

  Future<void> _resendCode() async {
    if (_isLoading || _isResending) return;

    setState(() => _isResending = true);

    try {
      final response =
          await AuthenticationService.forgotPassword(
        email: _emailController.text.trim(),
      );

      if (!mounted) return;

      _showMessage(
        response.message ??
            (response.success
                ? 'A new reset code has been sent.'
                : 'Unable to resend the reset code.'),
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

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;

    await _performRequest(() async {
      final response =
          await AuthenticationService.verifyResetCode(
        email: _emailController.text.trim(),
        code: _codeController.text.trim(),
      );

      if (!response.success) {
        throw Exception(
          response.message ?? 'Invalid reset code.',
        );
      }

      setState(() => _step = 2);
    });
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    await _performRequest(() async {
      final response =
          await AuthenticationService.resetPassword(
        email: _emailController.text.trim(),
        code: _codeController.text.trim(),
        newPassword: _passwordController.text,
      );

      if (!response.success) {
        throw Exception(
          response.message ?? 'Unable to reset password.',
        );
      }

      if (!mounted) return;

      _showMessage(
        response.message ?? 'Password changed successfully.',
      );

      Navigator.pop(context);
    });
  }

  Future<void> _performRequest(
    Future<void> Function() request,
  ) async {
    setState(() => _isLoading = true);

    try {
      await request();
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String get _title {
    switch (_step) {
      case 0:
        return 'Forgot password?';
      case 1:
        return 'Verify reset code';
      default:
        return 'Create new password';
    }
  }

  String get _description {
    switch (_step) {
      case 0:
        return 'Enter your account email address and we will send you a reset code.';
      case 1:
        return 'Enter the code sent to ${_emailController.text.trim()}.';
      default:
        return 'Choose a new password for your StudyFlow account.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Password recovery')),
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
                      Icons.lock_reset_rounded,
                      size: 64,
                    ),
                    const SizedBox(height: 24),

                    Text(
                      _title,
                      style: Theme.of(context)
                          .textTheme
                          .headlineLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _description,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 28),

                    if (_step == 0) ...[
                      AppTextField(
                        controller: _emailController,
                        label: 'Email address',
                        hint: 'Enter your account email',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email.';
                          }

                          if (!RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          ).hasMatch(value.trim())) {
                            return 'Enter a valid email address.';
                          }

                          return null;
                        },
                      ),
                    ],

                    if (_step == 1) ...[
                      AppTextField(
                        controller: _codeController,
                        label: 'Reset code',
                        hint: 'Enter the code from your email',
                        prefixIcon: Icons.pin_outlined,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the reset code.';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 8),

                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed:
                              (_isLoading || _isResending)
                                  ? null
                                  : _resendCode,
                          child: _isResending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Resend reset code',
                                ),
                        ),
                      ),
                    ],

                    if (_step == 2) ...[
                      AppTextField(
                        controller: _passwordController,
                        label: 'New password',
                        hint: 'Enter your new password',
                        prefixIcon: Icons.lock_outline,
                        obscureText: _obscurePassword,
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
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a new password.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      AppTextField(
                        controller: _confirmPasswordController,
                        label: 'Confirm new password',
                        hint: 'Enter your new password again',
                        prefixIcon: Icons.lock_outline,
                        obscureText: _obscureConfirmation,
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscureConfirmation =
                                  !_obscureConfirmation;
                            });
                          },
                          icon: Icon(
                            _obscureConfirmation
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password.';
                          }

                          if (value != _passwordController.text) {
                            return 'Passwords do not match.';
                          }

                          return null;
                        },
                      ),
                    ],

                    const SizedBox(height: 28),

                    AppButton(
                      text: _step == 0
                          ? 'Send reset code'
                          : _step == 1
                              ? 'Verify code'
                              : 'Reset password',
                      isLoading: _isLoading,
                      onPressed: _step == 0
                          ? _sendCode
                          : _step == 1
                              ? _verifyCode
                              : _resetPassword,
                    ),

                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isLoading || _isResending
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Back to sign in'),
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
