import 'package:dinadrawing/firebase_options.dart';
import 'package:dinadrawing/providers/theme_provider.dart';
import 'package:dinadrawing/screens/onboarding/onboarding.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const Color _brandGold = Color(0xFFF2B73F);

ThemeData _buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: _brandGold,
    brightness: brightness,
    surface: isDark ? const Color(0xFF1E1E1E) : Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor:
        isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
    cardColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
    dividerColor: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE),
    dialogTheme: DialogThemeData(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
    ),
    textTheme: ThemeData(brightness: brightness).textTheme.apply(
          bodyColor: colorScheme.onSurface,
          displayColor: colorScheme.onSurface,
        ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('Startup: initializing Flutter app');

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Startup: Firebase initialized successfully for ${DefaultFirebaseOptions.currentPlatform.projectId}');
  } catch (error, stackTrace) {
    debugPrint('Startup: Firebase initialization skipped or failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  debugPrint('Startup: launching app shell');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          debugPrint('Theme applied: ${themeProvider.themeMode}');

          return MaterialApp(
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            theme: _buildAppTheme(Brightness.light),
            darkTheme: _buildAppTheme(Brightness.dark),
            home: const OnboardingPage(),
          );
        },
      ),
    );
  }
}
