import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../widgets/profile_avatar.dart';

class ProfileEditorScreen extends StatefulWidget {
  const ProfileEditorScreen({
    super.key,
    required this.apiClient,
    required this.profile,
  });

  final ApiClient apiClient;
  final UserProfileModel profile;

  @override
  State<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<ProfileEditorScreen> {
  late String _avatar;
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _savingAvatar = false;
  bool _changingPassword = false;
  String? _avatarError;
  String? _passwordError;
  String? _passwordMessage;

  @override
  void initState() {
    super.initState();
    _avatar = widget.profile.avatarId;
  }

  Future<void> _saveAvatar() async {
    setState(() {
      _savingAvatar = true;
      _avatarError = null;
    });
    try {
      await widget.apiClient.updateProfile(avatarId: _avatar);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _savingAvatar = false;
          _avatarError = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _changePassword() async {
    final current = _currentPassword.text;
    final next = _newPassword.text;
    if (current.isEmpty) {
      setState(() {
        _passwordError = 'Enter your current password.';
        _passwordMessage = null;
      });
      return;
    }
    if (next.length < 6) {
      setState(() {
        _passwordError = 'New password must be at least 6 characters.';
        _passwordMessage = null;
      });
      return;
    }
    if (next != _confirmPassword.text) {
      setState(() {
        _passwordError = 'The new passwords do not match.';
        _passwordMessage = null;
      });
      return;
    }

    setState(() {
      _changingPassword = true;
      _passwordError = null;
      _passwordMessage = null;
    });
    try {
      await widget.apiClient.changePassword(
        currentPassword: current,
        newPassword: next,
      );
      if (!mounted) return;
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      setState(() {
        _changingPassword = false;
        _passwordMessage = 'Password updated.';
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _changingPassword = false;
          _passwordError = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Profile settings')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(child: ProfileAvatar(avatarId: _avatar, radius: 44)),
            const SizedBox(height: 20),
            _lockedField('Display name', widget.profile.displayName),
            const SizedBox(height: 12),
            _lockedField(
              'Username',
              widget.profile.username == null
                  ? 'Not set'
                  : '@${widget.profile.username}',
            ),
            const SizedBox(height: 8),
            const Text(
              'Name and username are set during signup and cannot be changed.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 24),
            const Text(
              'CHANGE AVATAR',
              style: TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: freeAvatars
                  .map(
                    (avatar) => Semantics(
                      label: avatar.name,
                      selected: _avatar == avatar.id,
                      button: true,
                      child: InkWell(
                        onTap: _savingAvatar
                            ? null
                            : () => setState(() => _avatar = avatar.id),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 96,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _avatar == avatar.id
                                  ? AppColors.gold
                                  : Colors.white12,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              ProfileAvatar(avatarId: avatar.id),
                              const SizedBox(height: 6),
                              Text(avatar.name),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            if (_avatarError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _avatarError!,
                  style: const TextStyle(color: AppColors.red),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _savingAvatar ? null : _saveAvatar,
              child: Text(_savingAvatar ? 'SAVING...' : 'SAVE AVATAR'),
            ),
            const SizedBox(height: 28),
            const Divider(color: Colors.white12),
            const SizedBox(height: 16),
            const Text(
              'CHANGE PASSWORD',
              style: TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Available for email and password accounts. Google account passwords are managed by Google.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            _passwordField(_currentPassword, 'Current password'),
            const SizedBox(height: 12),
            _passwordField(_newPassword, 'New password'),
            const SizedBox(height: 12),
            _passwordField(_confirmPassword, 'Confirm new password'),
            if (_passwordError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _passwordError!,
                  style: const TextStyle(color: AppColors.red),
                ),
              ),
            if (_passwordMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _passwordMessage!,
                  style: const TextStyle(color: AppColors.green),
                ),
              ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _changingPassword ? null : _changePassword,
              child: Text(
                _changingPassword ? 'UPDATING...' : 'UPDATE PASSWORD',
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _lockedField(String label, String value) => InputDecorator(
    decoration: InputDecoration(labelText: label),
    child: Text(value, style: const TextStyle(color: AppColors.textSecondary)),
  );

  Widget _passwordField(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        obscureText: true,
        enabled: !_changingPassword,
        decoration: InputDecoration(labelText: label),
      );

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }
}
