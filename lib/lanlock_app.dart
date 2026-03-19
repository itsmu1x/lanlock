import 'package:flutter/material.dart';

import 'ui/profiles_page.dart';

class LanlockApp extends StatelessWidget {
  const LanlockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lanlock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF070A12),
        canvasColor: const Color(0xFF070A12),
      ),
      home: const ProfilesPage(),
    );
  }
}

