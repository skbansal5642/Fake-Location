import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() => runApp(const FakeLocationApp());

class FakeLocationApp extends StatelessWidget {
  const FakeLocationApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Fake Location',
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.teal,
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      );
}
