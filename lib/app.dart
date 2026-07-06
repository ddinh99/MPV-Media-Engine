// lib/app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'constants/theme.dart';
import 'providers/dsp_provider.dart';
import 'screens/home_screen.dart';

class MvpSoundEngineApp extends StatelessWidget {
  const MvpSoundEngineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DspProvider(),
      child: MaterialApp(
        title: 'MVP Sound Engine',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: const HomeScreen(),
      ),
    );
  }
}
