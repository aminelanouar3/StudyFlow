import 'package:flutter/material.dart';
import '../../models/auth_response.dart';
import '../../services/authentication_service.dart';

class ProfileScreen extends StatefulWidget {
  final dynamic user;
  final String initialFullName;
  final String initialEmail;
  final VoidCallback? onLogout;

  const ProfileScreen({
    super.key,
    required this.user,
    this.initialFullName = 'Student Name',
    this.initialEmail = 'student@email.com',
    this.onLogout,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}
class _ProfileScreenState extends State<ProfileScreen> {
  late String _fullName;
  late String _email;

  bool _notificationsEnabled = true;
  String _language = 'English';
  bool _isLoading = true;
  String? _profileError;

  final Color _primaryColor = const Color(0xFF14B8A6);
  final Color _backgroundColor = const Color(0xFFF7F9FC);


  @override
void initState() {
  super.initState();

  _fullName = widget.initialFullName;
  _email = widget.initialEmail;

  _loadProfile();
}

Future<void> _loadProfile() async {
  try {
    // Get the authentication token from the logged-in user.
    final AuthResponse auth = widget.user as AuthResponse;
    final token = auth.token;

    if (token == null || token.isEmpty) {
      throw Exception('Authentication token is missing.');
    }

    // Request the user's profile from the SOAP backend.
    final response = await AuthenticationService.getProfile(
      token: token,
    );

    if (!mounted) return;

    if (response.success) {
      setState(() {
        _fullName = response.fullName ?? _fullName;
        _email = response.email ?? _email;
        _profileError = null;
        _isLoading = false;
      });
    } else {
      setState(() {
        _profileError = response.message.isNotEmpty
            ? response.message
            : 'Unable to load your profile.';
        _isLoading = false;
      });
    }
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _profileError = e.toString();
      _isLoading = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Color(0xFF172B4D),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 28),

            _buildSectionTitle('Personal information'),
            const SizedBox(height: 12),

            _buildSettingTile(
              icon: Icons.person_outline,
              title: 'Full name',
              subtitle: _fullName,
              onTap: _showEditNameDialog,
            ),
            _buildSettingTile(
              icon: Icons.email_outlined,
              title: 'Email address',
              subtitle: _email,
              onTap: _showChangeEmailDialog,
            ),

            const SizedBox(height: 28),
            _buildSectionTitle('Security'),
            const SizedBox(height: 12),

            _buildSettingTile(
              icon: Icons.lock_outline,
              title: 'Change password',
              subtitle: 'Update your account password',
              onTap: _showChangePasswordDialog,
            ),

            const SizedBox(height: 28),
            _buildSectionTitle('Preferences'),
            const SizedBox(height: 12),

            _buildSwitchTile(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'Receive reminders about your tasks',
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() => _notificationsEnabled = value);
              },
            ),

            _buildLanguageTile(),

            const SizedBox(height: 28),
            _buildSectionTitle('Account'),
            const SizedBox(height: 12),

            _buildSettingTile(
              icon: Icons.logout,
              title: 'Log out',
              subtitle: 'Sign out of your account',
              iconColor: Colors.redAccent,
              titleColor: Colors.redAccent,
              onTap: _showLogoutDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: _primaryColor.withOpacity(0.12),
            child: Icon(
              Icons.person,
              size: 45,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _fullName,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Color(0xFF172B4D),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _email,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'StudyFlow Student',
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF172B4D),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? titleColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 5,
        ),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: (iconColor ?? _primaryColor).withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: iconColor ?? _primaryColor,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: titleColor ?? const Color(0xFF172B4D),
            fontSize: 14,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Colors.grey,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 5,
        ),
        secondary: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _primaryColor),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF172B4D),
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
        activeColor: _primaryColor,
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildLanguageTile() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.language,
              color: _primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Language',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF172B4D),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Choose your application language',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _language,
              items: const [
                DropdownMenuItem(
                  value: 'English',
                  child: Text('English'),
                ),
                DropdownMenuItem(
                  value: 'Français',
                  child: Text('Français'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _language = value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditNameDialog() async {
    final controller = TextEditingController(text: _fullName);

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit full name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Full name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;

              setState(() => _fullName = name);
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();
  }

  Future<void> _showChangeEmailDialog() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change email address'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'New email address',
            hintText: 'example@email.com',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final email = controller.text.trim();
              if (!_isValidEmail(email)) return;

              Navigator.pop(dialogContext);
              _showEmailVerificationDialog(email);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    controller.dispose();
  }

  Future<void> _showEmailVerificationDialog(String newEmail) async {
    final codeController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Verify new email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter the 6-digit verification code sent to $newEmail.'),
            const SizedBox(height: 18),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Verification code',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (codeController.text.trim().length != 6) return;

              // Connect this action to email verification.
              // Keep the existing email until the server confirms verification.
              Navigator.pop(dialogContext);
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );

    codeController.dispose();
  }

  Future<void> _showChangePasswordDialog() async {
    final formKey = GlobalKey<FormState>();
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change password'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: oldPasswordController,
                    obscureText: obscureOld,
                    decoration: InputDecoration(
                      labelText: 'Current password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureOld
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setDialogState(() => obscureOld = !obscureOld);
                        },
                      ),
                    ),
                    validator: (value) =>
                        value == null || value.isEmpty
                            ? 'Enter your current password'
                            : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: newPasswordController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'New password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNew
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setDialogState(() => obscureNew = !obscureNew);
                        },
                      ),
                    ),
                    validator: (value) =>
                        value == null || value.length < 8
                            ? 'Use at least 8 characters'
                            : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm new password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setDialogState(
                            () => obscureConfirm = !obscureConfirm,
                          );
                        },
                      ),
                    ),
                    validator: (value) =>
                        value != newPasswordController.text
                            ? 'Passwords do not match'
                            : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;

                // Connect this action to the password-change operation.
                Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  Future<void> _showLogoutDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out'),
        content: const Text(
          'Are you sure you want to log out of your account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.onLogout?.call();
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(
      r'^[\w.+-]+@[\w-]+\.[\w.-]+$',
    ).hasMatch(email);
  }
}