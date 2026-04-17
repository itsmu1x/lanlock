import 'package:flutter/material.dart';

/// Visual category for [showLanlockToast].
enum LanlockToastKind {
  /// Positive feedback (copied, saved, deleted).
  success,

  /// Failures and validation problems.
  error,

  /// Neutral notices (hints, cancelled actions).
  info,
}

/// Floating toast styled for LanLock (dark shell, accent border, soft shadow).
///
/// Uses [ScaffoldMessenger] under the hood; safe from dialogs if the app root
/// provides a [ScaffoldMessenger].
void showLanlockToast(
  BuildContext context,
  String message, {
  LanlockToastKind kind = LanlockToastKind.info,
  Duration? duration,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger.clearSnackBars();

  const surface = Color(0xFF141A2E);

  final IconData icon;
  final Color accent;
  switch (kind) {
    case LanlockToastKind.success:
      icon = Icons.check_circle_rounded;
      accent = Color(0xFF5FE1B5);
    case LanlockToastKind.error:
      icon = Icons.error_outline_rounded;
      accent = Color(0xFFFF7A8A);
    case LanlockToastKind.info:
      icon = Icons.info_outline_rounded;
      accent = Color(0xFFB39DFF);
  }

  final d = duration ??
      switch (kind) {
        LanlockToastKind.error => const Duration(milliseconds: 4200),
        _ => const Duration(milliseconds: 2800),
      };

  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 22),
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      clipBehavior: Clip.none,
      duration: d,
      dismissDirection: DismissDirection.horizontal,
      content: DecoratedBox(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: accent.withValues(alpha: 0.42),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.48),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: accent.withValues(alpha: 0.14),
              blurRadius: 24,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accent, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFF2F4FC),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    letterSpacing: 0.12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
