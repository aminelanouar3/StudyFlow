
import 'package:flutter/material.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _sendRequest() {
    if (_emailController.text.trim().isEmpty ||
        !_emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password recovery will be implemented in the backend.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 30),
            const Icon(
              Icons.lock_reset_rounded,
              size: 65,
              color: Color(0xFF6C63FF),
            ),
            const SizedBox(height: 25),
            const Text(
              'Forgot Password?',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.bold,
                color: Color(0xFF29264A),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Enter the email address associated with your account. '
              'We will use it to help you recover access.',
              style: TextStyle(
                color: Colors.grey,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 30),
            CustomTextField(
              label: 'Email address',
              hint: 'Enter your email',
              prefixIcon: Icons.email_outlined,
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 25),
            CustomButton(
              text: 'Continue',
              onPressed: _sendRequest,
            ),
          ],
        ),
      ),
    );
  }
}
