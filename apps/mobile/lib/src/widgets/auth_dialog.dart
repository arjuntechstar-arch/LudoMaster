import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../screens/privacy_policy_screen.dart';
import '../theme/app_colors.dart';
import 'google_account_buttons.dart';
import 'profile_avatar.dart';

/// Modal dialog providing user Sign In, Sign Up, and welcoming the player by display name.
class AuthDialog extends StatefulWidget {
  final ApiClient apiClient;
  final VoidCallback onAuthenticated;

  const AuthDialog({
    super.key,
    required this.apiClient,
    required this.onAuthenticated,
  });

  @override
  State<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<AuthDialog> {
  bool _isSignUp = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successPlayerId;
  String? _successName;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  String _selectedAvatarId = 'avatar_0';

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.apiClient.isGuest == true;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      return;
    }
    if (_isSignUp && !await _validateSignupProfile()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      Map<String, dynamic> result;
      if (_isSignUp) {
        if (widget.apiClient.isGuest == true) {
          result = await widget.apiClient.upgradeGuest(
            email: email,
            password: password,
            displayName: name,
            username: _normalizedUsername,
            avatarId: _selectedAvatarId,
          );
        } else {
          result = await widget.apiClient.register(
            email: email,
            password: password,
            displayName: name,
            username: _normalizedUsername,
            avatarId: _selectedAvatarId,
          );
        }
      } else {
        result = await widget.apiClient.login(email: email, password: password);
      }

      final playerId = result['player_id'] as String? ?? 'LM-XXXXX';
      final displayName =
          result['display_name'] as String? ?? (_isSignUp ? name : 'Player');

      setState(() {
        _isLoading = false;
        _successPlayerId = playerId;
        _successName = displayName;
      });

      widget.onAuthenticated();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String get _normalizedUsername => _usernameController.text
      .trim()
      .replaceFirst(RegExp(r'^@'), '')
      .toLowerCase();

  Future<bool> _validateSignupProfile() async {
    final displayName = _nameController.text.trim();
    final username = _normalizedUsername;
    if (displayName.length < 2 || displayName.length > 30) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Display name must be 2 to 30 characters',
        );
      }
      return false;
    }
    if (!RegExp(r'^[a-z][a-z0-9_]{2,19}$').hasMatch(username)) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Username must be 3 to 20 characters and start with a letter',
        );
      }
      return false;
    }
    try {
      final result = await widget.apiClient.checkUsernameAvailability(username);
      if (!mounted) return false;
      if (result['available'] != true) {
        setState(
          () => _errorMessage =
              result['reason'] as String? ?? 'This username is already taken.',
        );
        return false;
      }
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _errorMessage = error.toString().replaceFirst('Exception: ', ''),
        );
      }
      return false;
    }
    if (!mounted) return false;
    setState(() => _errorMessage = null);
    return true;
  }

  Future<void> _handleGuest() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await widget.apiClient.loginGuest();
      widget.onAuthenticated();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Guest login failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: const Color(0xFF131A2E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: _successPlayerId != null
              ? _buildSuccessView()
              : _buildFormView(),
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.5),
                blurRadius: 16,
              ),
            ],
          ),
          child: const Icon(Icons.check_circle, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 16),
        Text(
          'WELCOME, ${_successName?.toUpperCase()}!',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isSignUp
              ? 'Your name and username are set. You can change your avatar later.'
              : 'You are signed in and ready to play.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 20),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 4,
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'START PLAYING NOW',
              style: TextStyle(
                color: Color(0xFF1E1B4B),
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.casino, color: AppColors.gold, size: 28),
                const SizedBox(width: 8),
                Text(
                  _isSignUp ? 'CREATE ACCOUNT' : 'SIGN IN',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white60),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _isSignUp
              ? 'Sign up to save progress and play with friends!'
              : 'Sign in to access your stats, wallet, and play with friends.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 18),

        // Toggle Switch
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2640),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _isSignUp = false;
                    _errorMessage = null;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: !_isSignUp ? AppColors.gold : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Sign In',
                      style: TextStyle(
                        color: !_isSignUp
                            ? const Color(0xFF0F172A)
                            : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _isSignUp = true;
                    _errorMessage = null;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _isSignUp ? AppColors.gold : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Sign Up',
                      style: TextStyle(
                        color: _isSignUp
                            ? const Color(0xFF0F172A)
                            : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Error message if any
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Display Name (if sign up)
        if (_isSignUp) ...[
          TextField(
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Display Name',
              hintText: 'e.g. MasterDice',
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              prefixIcon: const Icon(
                Icons.person_outline,
                color: AppColors.gold,
              ),
              filled: true,
              fillColor: const Color(0xFF1A2238),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 16,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usernameController,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.none,
            autocorrect: false,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Username',
              hintText: 'e.g. master_dice',
              prefixText: '@',
              helperText:
                  'Set once during signup; friends can find you by username.',
              helperMaxLines: 2,
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              prefixIcon: const Icon(
                Icons.alternate_email,
                color: AppColors.gold,
              ),
              filled: true,
              fillColor: const Color(0xFF1A2238),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 16,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'CHOOSE YOUR AVATAR',
            style: TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: freeAvatars
                .map(
                  (avatar) => Semantics(
                    label: avatar.name,
                    selected: _selectedAvatarId == avatar.id,
                    button: true,
                    child: InkWell(
                      onTap: _isLoading
                          ? null
                          : () => setState(() => _selectedAvatarId = avatar.id),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 70,
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2238),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedAvatarId == avatar.id
                                ? AppColors.gold
                                : Colors.white12,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ProfileAvatar(avatarId: avatar.id, radius: 17),
                            const SizedBox(height: 4),
                            Text(
                              avatar.name,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          const Text(
            'Name and username cannot be changed after signup. You can change your avatar later.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 12),
        ],

        GoogleAccountButtons(
          apiClient: widget.apiClient,
          link: widget.apiClient.isGuest == true,
          signupDisplayName: _isSignUp ? _nameController.text : null,
          signupUsername: _isSignUp ? _normalizedUsername : null,
          signupAvatarId: _isSignUp ? _selectedAvatarId : null,
          validateSignupProfile: _isSignUp ? _validateSignupProfile : null,
          onSignedIn: (result) {
            if (!mounted) return;
            setState(() {
              _successPlayerId = result['player_id'] as String?;
              _successName = result['display_name'] as String?;
            });
            widget.onAuthenticated();
          },
        ),
        const SizedBox(height: 12),

        // Email field
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Email Address',
            hintText: 'player@example.com',
            labelStyle: const TextStyle(color: AppColors.textSecondary),
            prefixIcon: const Icon(Icons.email_outlined, color: AppColors.gold),
            filled: true,
            fillColor: const Color(0xFF1A2238),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 16,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Password field
        TextField(
          controller: _passwordController,
          obscureText: true,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: 'At least 6 characters',
            labelStyle: const TextStyle(color: AppColors.textSecondary),
            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.gold),
            filled: true,
            fillColor: const Color(0xFF1A2238),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 16,
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Submit Button
        SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 4,
            ),
            onPressed: _isLoading ? null : _handleSubmit,
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    _isSignUp ? 'CREATE ACCOUNT' : 'SIGN IN',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),

        // Quick Guest option
        Center(
          child: TextButton.icon(
            icon: const Icon(
              Icons.person_pin,
              size: 18,
              color: AppColors.textSecondary,
            ),
            label: const Text(
              'Continue as Guest',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            onPressed: _isLoading ? null : _handleGuest,
          ),
        ),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PrivacyPolicyScreen(),
              ),
            ),
            child: const Text('Privacy Policy'),
          ),
        ),
      ],
    );
  }
}
