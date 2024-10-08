import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'onboarding_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_windowmanager/flutter_windowmanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
      name: "opensource", options: DefaultFirebaseOptions.currentPlatform);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Disable screenshots and screen recording for Android
    if (!kIsWeb && Theme.of(context).platform == TargetPlatform.android) {
      FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
    }

    return MaterialApp(
      title: 'PDF Viewer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const OnboardingScreen(),
    );
  }
}
