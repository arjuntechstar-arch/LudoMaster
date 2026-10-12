import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/api_client.dart';
import 'google_button_stub.dart'
    if (dart.library.js_interop) 'google_button_web.dart'
    as google_button;

class GoogleAccountButtons extends StatefulWidget {
  const GoogleAccountButtons({
    super.key,
    required this.apiClient,
    required this.onSignedIn,
    this.link = false,
    this.signupDisplayName,
    this.signupUsername,
    this.signupAvatarId,
    this.validateSignupProfile,
  });
  final ApiClient apiClient;
  final ValueChanged<Map<String, dynamic>> onSignedIn;
  final bool link;
  final String? signupDisplayName;
  final String? signupUsername;
  final String? signupAvatarId;
  final Future<bool> Function()? validateSignupProfile;

  @override
  State<GoogleAccountButtons> createState() => _GoogleAccountButtonsState();
}

class _GoogleAccountButtonsState extends State<GoogleAccountButtons> {
  static Future<void>? _googleInitialization;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _subscription;
  Map<String, dynamic> _providers = {};
  bool _ready = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _providers = await widget.apiClient.getAuthProviders();
      if (_providers['google_enabled'] == true) {
        final clientId = _providers['google_client_id'] as String?;
        _googleInitialization ??= GoogleSignIn.instance.initialize(
          clientId: kIsWeb ? clientId : null,
          serverClientId: kIsWeb ? null : clientId,
        );
        await _googleInitialization;
        if (!mounted) return;
        _subscription = GoogleSignIn.instance.authenticationEvents.listen(
          (event) {
            if (event is GoogleSignInAuthenticationEventSignIn) {
              _acceptGoogle(event.user);
            }
          },
          onError: (Object error) {
            if (mounted) {
              setState(() {
                _busy = false;
                _error = 'Google sign-in could not be completed';
              });
            }
          },
        );
        _ready = true;
      }
    } catch (_) {
      _googleInitialization = null;
      _error = 'Google connections are currently unavailable';
    }
    if (mounted) setState(() {});
  }

  Future<void> _acceptGoogle(GoogleSignInAccount account) async {
    if (!mounted || _busy) return;
    if (widget.validateSignupProfile != null &&
        !await widget.validateSignupProfile!()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = account.authentication.idToken;
      if (token == null) {
        throw Exception('Google did not return a sign-in token');
      }
      final result = await widget.apiClient.signInWithGoogleToken(
        token,
        link: widget.link,
        displayName: widget.signupDisplayName,
        username: widget.signupUsername,
        avatarId: widget.signupAvatarId,
      );
      if (mounted) widget.onSignedIn(result);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _googleSignIn() async {
    try {
      await GoogleSignIn.instance.authenticate();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Google sign-in was cancelled or unavailable');
      }
    }
  }

  Future<void> _playGamesSignIn() async {
    if (widget.validateSignupProfile != null &&
        !await widget.validateSignupProfile!()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final code = await const MethodChannel('ludoplay/play_games')
          .invokeMethod<String>('signIn', {
            'serverClientId': _providers['play_games_server_client_id'],
          });
      if (code == null || code.isEmpty) {
        throw Exception('Play Games sign-in was cancelled');
      }
      final result = await widget.apiClient.signInWithPlayGamesCode(
        code,
        link: widget.link,
        displayName: widget.signupDisplayName,
        username: widget.signupUsername,
        avatarId: widget.signupAvatarId,
      );
      if (mounted) widget.onSignedIn(result);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_ready && kIsWeb)
        Center(child: google_button.buildGoogleWebButton())
      else
        OutlinedButton.icon(
          onPressed: _ready && !_busy ? _googleSignIn : null,
          icon: const Icon(Icons.account_circle),
          label: Text(
            widget.link ? 'Connect Google account' : 'Continue with Google',
          ),
        ),
      OutlinedButton.icon(
        onPressed:
            !kIsWeb &&
                defaultTargetPlatform == TargetPlatform.android &&
                _providers['play_games_enabled'] == true &&
                !_busy
            ? _playGamesSignIn
            : null,
        icon: const Icon(Icons.sports_esports),
        label: const Text('Connect Google Play Games'),
      ),
      if (kIsWeb)
        const Text(
          'Play Games accounts connect in the Android app.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 11),
        ),
      if (_busy) const LinearProgressIndicator(),
      if (!_ready && _providers.isNotEmpty)
        const Text(
          'Google sign-in is currently unavailable.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 11),
        ),
      if (_error != null)
        Text(
          _error!,
          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
        ),
    ],
  );
}
