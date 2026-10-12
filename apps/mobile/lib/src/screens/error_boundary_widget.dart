import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Error boundary widget wrapping critical screen hierarchies.
/// Catches unhandled widget tree build errors and displays a user-friendly recovery UI.
class ErrorBoundaryWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onReload;

  const ErrorBoundaryWidget({
    super.key,
    required this.child,
    this.onReload,
  });

  @override
  State<ErrorBoundaryWidget> createState() => _ErrorBoundaryWidgetState();
}

class _ErrorBoundaryWidgetState extends State<ErrorBoundaryWidget> {
  FlutterErrorDetails? _errorDetails;

  @override
  void initState() {
    super.initState();
  }

  void _resetError() {
    setState(() {
      _errorDetails = null;
    });
    widget.onReload?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorDetails != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      border: Border.all(color: Colors.redAccent, width: 2),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.redAccent,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Something Went Wrong',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'An unexpected visual rendering exception was intercepted safely by the LudoMaster error boundary.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _resetError,
                    icon: const Icon(Icons.refresh),
                    label: const Text('RELOAD GAME'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppColors.surface,
                          title: const Text('Error Diagnostics', style: TextStyle(color: AppColors.gold)),
                          content: SingleChildScrollView(
                            child: Text(
                              _errorDetails?.exceptionAsString() ?? 'No details captured.',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('CLOSE', style: TextStyle(color: AppColors.gold)),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('View Technical Diagnostics', style: TextStyle(color: AppColors.textMuted)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
