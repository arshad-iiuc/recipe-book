import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'screens/splash_screen.dart';
import 'services/recipe_cache.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Hive.initFlutter();
    await Hive.openBox<String>(recipeBoxName);
    await Hive.openBox<bool>(deletedBoxName);
  } catch (_) {
    // ponytail: without storage the app still works online. Upgrade path is
    // telling the user that offline mode is unavailable.
  }
  runApp(const RecipeApp());
}

ThemeData _theme(Brightness brightness) => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepOrange,
        brightness: brightness,
      ),
    );

class RecipeApp extends StatelessWidget {
  const RecipeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recipe Book',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: const SplashScreen(),
    );
  }
}
