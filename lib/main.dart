import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'screens/dish_list_screen.dart';
import 'state/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: const FoodManagerApp(),
    ),
  );
}

class FoodManagerApp extends StatelessWidget {
  const FoodManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kProjectName, // {MSSV}_FoodManager
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepOrange,
        useMaterial3: true,
      ),
      home: const DishListScreen(),
    );
  }
}
