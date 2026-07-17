import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:padelsquare_staff_app/auth_gate.dart';
import 'firebase_options.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const PadelSquareApp());
}

class PadelSquareApp extends StatelessWidget {
  const PadelSquareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PadelSquare Staff',
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      home: const AuthGate(),
    );
  }
}