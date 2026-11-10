
import 'package:flutter/material.dart';

import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../services/authentication_service.dart';
import '../../app/routes.dart';
import '../../services/session_manager.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await AuthenticationService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (response.success) {
        if (response.token != null) {
        await SessionManager.saveToken(response.token!);
        }
        Navigator.pushReplacementNamed(
        context,
        AppRoutes.home,
        arguments: response,
        );
        } else {
            ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.message)),
            );
        }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(26),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAE8FF),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(
                            Icons.school_rounded,
                            size: 42,
                            color: Color(0xFF6C63FF),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'StudyFlow',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF29264A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Organize your studies. Reach your goals.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 42),
                  const Text(
                    'Welcome back!',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in to continue your learning journey.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 28),
                  CustomTextField(
                    label: 'Email address',
                    hint: 'Enter your email',
                    prefixIcon: Icons.email_outlined,
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  CustomTextField(
                    label: 'Password',
                    hint: 'Enter your password',
                    prefixIcon: Icons.lock_outline,
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.forgotPassword,
                        );
                      },
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  CustomButton(
                    text: 'Sign In',
                    onPressed: _login,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        const Text("Don't have an account? "),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.register,
                            );
                          },
                          child: const Text(
                            'Create account',
                            style: TextStyle(
                              color: Color(0xFF6C63FF),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
