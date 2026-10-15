import 'package:flutter/material.dart';

import 'reference_ludo_lobby_screen.dart';

/// Overflow-safe presentation of the reference lobby.
///
/// The original lobby owns all game interactions and visual details on a
/// 706x1600 logical canvas. This wrapper gives it those exact constraints and
/// then scales the complete canvas using both available dimensions, preventing
/// the desktop/web layout from being enlarged by width and cropped vertically.
class ReferenceLudoLobbyV2Screen extends StatelessWidget {
  const ReferenceLudoLobbyV2Screen({super.key});

  static const double _designWidth = 706;
  static const double _designHeight = 1600;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1733),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.center,
                child: SizedBox(
                  width: _designWidth,
                  height: _designHeight,
                  child: MediaQuery(
                    // The reference canvas uses fixed pixel-proportioned boxes.
                    // Normalize text within that canvas so accessibility/browser
                    // scaling cannot make labels overflow their fixed artwork.
                    data: mediaQuery.copyWith(
                      size: const Size(_designWidth, _designHeight),
                      textScaler: const TextScaler.linear(0.82),
                    ),
                    child: const ReferenceLudoLobbyScreen(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
