
import 'package:flutter/material.dart';

import '../../models/auth_response.dart';
import '../../services/authentication_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AuthResponse? _profile;
  bool _isLoading = true;
  bool _isUpdating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<String> _getToken() async {
    final token = await SessionService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Your session has expired. Please sign in again.');
    }

    return token;
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await _getToken();
      final response =
          await AuthenticationService.getProfile(token: token);

      if (!response.success) {
        throw Exception(response.message ?? 'Unable to load your profile.');
      }

      if (!mounted) return;

      setState(() {
        _profile = response;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String _getInitials(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) return '?';

    final parts = fullName.trim().split(RegExp(r'\s+'));

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<List<String>?> _showEditDialog({
    required String title,
    required String fieldLabel,
    required String initialValue,
    required TextInputType keyboardType,
  }) {
    return showDialog<List<String>>(
      context: context,
      builder: (_) => _EditInformationDialog(
        title: title,
        fieldLabel: fieldLabel,
        initialValue: initialValue,
        keyboardType: keyboardType,
      ),
    );
  }

  Future<String?> _showVerificationDialog() {
    return showDialog<String>(
      context: context,
      builder: (_) => const _VerificationCodeDialog(),
    );
  }

  Future<void> _editFullName() async {
    final result = await _showEditDialog(
      title: 'Change full name',
      fieldLabel: 'New full name',
      initialValue: _profile?.fullName ?? '',
      keyboardType: TextInputType.name,
    );

    if (!mounted || result == null) return;

    final newName = result[0];
    final password = result[1];

    if (newName.isEmpty || password.isEmpty) {
      _showMessage('Please complete both fields.');
      return;
    }

    if (newName == _profile?.fullName) {
      _showMessage('Your name has not changed.');
      return;
    }

    setState(() => _isUpdating = true);

    try {
      final token = await _getToken();

      final response = await AuthenticationService.changeFullName(
        token: token,
        currentPassword: password,
        newFullName: newName,
      );

      if (!response.success) {
        throw Exception(response.message ?? 'Unable to change your name.');
      }

      await _loadProfile();

      if (mounted) {
        _showMessage('Your full name was updated successfully.');
      }
    } catch (e) {
      if (mounted) {
        _showMessage(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _editEmail() async {
    final result = await _showEditDialog(
      title: 'Change email address',
      fieldLabel: 'New email address',
      initialValue: _profile?.email ?? '',
      keyboardType: TextInputType.emailAddress,
    );

    if (!mounted || result == null) return;

    final newEmail = result[0];
    final password = result[1];

    if (newEmail.isEmpty || password.isEmpty) {
      _showMessage('Please complete both fields.');
      return;
    }

    if (newEmail == _profile?.email) {
      _showMessage('Your email address has not changed.');
      return;
    }

    if (!newEmail.contains('@') || !newEmail.contains('.')) {
      _showMessage('Please enter a valid email address.');
      return;
    }

    setState(() => _isUpdating = true);

    try {
      final token = await _getToken();

      final requestResponse =
          await AuthenticationService.requestEmailChange(
        token: token,
        currentPassword: password,
        newEmail: newEmail,
      );

      if (!requestResponse.success) {
        throw Exception(
          requestResponse.message ?? 'Unable to request email change.',
        );
      }

      if (!mounted) return;

      _showMessage('Verification code sent to your new email.');

      final code = await _showVerificationDialog();

      if (!mounted || code == null) return;

      if (code.isEmpty) {
        _showMessage('Please enter the verification code.');
        return;
      }

      final verificationResponse =
          await AuthenticationService.verifyEmailChange(
        token: token,
        code: code,
      );

      if (!verificationResponse.success) {
        throw Exception(
          verificationResponse.message ?? 'Email verification failed.',
        );
      }

      await _loadProfile();

      if (mounted) {
        _showMessage('Your email address was updated successfully.');
      }
    } catch (e) {
      if (mounted) {
        _showMessage(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Widget _buildInformationTile({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onEdit,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      leading: Icon(icon, color: AppColors.primary),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      trailing: IconButton(
        tooltip: 'Edit $title',
        onPressed: _isUpdating ? null : onEdit,
        icon: const Icon(
          Icons.edit_outlined,
          color: AppColors.primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.screenPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 52,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to load profile',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadProfile,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final profile = _profile!;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadProfile,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppDimensions.screenPadding),
            children: [
              const SizedBox(height: 28),
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    _getInitials(profile.fullName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              Text(
                'Personal Information',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _buildInformationTile(
                      title: 'Full Name',
                      value: profile.fullName ?? 'Not available',
                      icon: Icons.person_outline,
                      onEdit: _editFullName,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildInformationTile(
                      title: 'Email Address',
                      value: profile.email ?? 'Not available',
                      icon: Icons.email_outlined,
                      onEdit: _editEmail,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_isUpdating)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.15),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
  }
}

// Owns and disposes its controllers after the dialog is removed.
class _EditInformationDialog extends StatefulWidget {
  final String title;
  final String fieldLabel;
  final String initialValue;
  final TextInputType keyboardType;

  const _EditInformationDialog({
    required this.title,
    required this.fieldLabel,
    required this.initialValue,
    required this.keyboardType,
  });

  @override
  State<_EditInformationDialog> createState() =>
      _EditInformationDialogState();
}

class _EditInformationDialogState extends State<_EditInformationDialog> {
  late final TextEditingController _valueController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _valueController = TextEditingController(text: widget.initialValue);
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _valueController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _valueController,
            keyboardType: widget.keyboardType,
            decoration: InputDecoration(
              labelText: widget.fieldLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Current password',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, [
              _valueController.text.trim(),
              _passwordController.text,
            ]);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// Owns and disposes the verification controller.
class _VerificationCodeDialog extends StatefulWidget {
  const _VerificationCodeDialog();

  @override
  State<_VerificationCodeDialog> createState() =>
      _VerificationCodeDialogState();
}

class _VerificationCodeDialogState extends State<_VerificationCodeDialog> {
  late final TextEditingController _codeController;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Verify your new email'),
      content: TextField(
        controller: _codeController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Verification code',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, _codeController.text.trim());
          },
          child: const Text('Verify'),
        ),
      ],
    );
  }
}
