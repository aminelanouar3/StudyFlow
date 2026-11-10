
import 'package:flutter/material.dart';

import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../services/authentication_service.dart';
import '../../app/routes.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await AuthenticationService.register(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (response.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully. Please sign in.'),
          ),
        );

        Navigator.pushReplacementNamed(context, AppRoutes.login);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message)),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: $e')),
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
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 10, 26, 30),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF29264A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Join StudyFlow and organize your studies.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 30),
                CustomTextField(
                  label: 'Full name',
                  hint: 'Enter your full name',
                  prefixIcon: Icons.person_outline,
                  controller: _nameController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                CustomTextField(
                  label: 'Email address',
                  hint: 'Enter your email',
                  prefixIcon: Icons.email_outlined,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null ||
                        !value.contains('@') ||
                        !value.contains('.')) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                CustomTextField(
                  label: 'Password',
                  hint: 'Create a password',
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
                    if (value == null || value.length < 8) {
                      return 'Password must contain at least 8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                CustomTextField(
                  label: 'Confirm password',
                  hint: 'Confirm your password',
                  prefixIcon: Icons.lock_outline,
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword =
                            !_obscureConfirmPassword;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),
                CustomButton(
                  text: 'Create Account',
                  onPressed: _register,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 20),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      const Text('Already have an account? '),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.login,
                          );
                        },
                        child: const Text(
                          'Sign in',
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
    );
  }
}
