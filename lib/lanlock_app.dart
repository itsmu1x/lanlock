import 'package:flutter/material.dart';

import 'ui/master_lock_page.dart';

class LanlockApp extends StatelessWidget {
  const LanlockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LanLock v2',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF070A12),
        canvasColor: const Color(0xFF070A12),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF141A2E),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Colors.deepPurpleAccent.withValues(alpha: 0.35),
            ),
          ),
          contentTextStyle: const TextStyle(
            color: Color(0xFFF2F4FC),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ),
      home: const MasterLockPage(),
    );
  }
}

