import 'package:flutter/material.dart';

class ThemeProvider extends StatefulWidget {
  final Widget child;

  const ThemeProvider({super.key, required this.child});

  static ThemeProviderState of(BuildContext context) {
    return context.findAncestorStateOfType<ThemeProviderState>()!;
  }

  @override
  ThemeProviderState createState() => ThemeProviderState();
}

class ThemeProviderState extends State<ThemeProvider> {
  bool isDarkMode = false;

  void toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return InheritedThemeProvider(
      data: this,
      child: widget.child,
    );
  }
}

class InheritedThemeProvider extends InheritedWidget {
  final ThemeProviderState data;

  const InheritedThemeProvider({
    super.key,
    required this.data,
    required super.child, // Gunakan super parameter
  });

  @override
  bool updateShouldNotify(InheritedThemeProvider oldWidget) => true;
}