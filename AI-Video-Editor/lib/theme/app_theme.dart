import 'package:flutter/material.dart';

class AppTheme {
  // Core dark color scheme (Material 3)
  static final ColorScheme darkScheme = ColorScheme.dark(
    primary: Color(0xFF6C63FF),
    onPrimary: Colors.white,
    secondary: Color(0xFF00D1FF),
    onSecondary: Colors.black,
    surface: Color(0xFF121212),
    onSurface: Colors.white70,
    background: Color(0xFF0F0F12),
    onBackground: Colors.white70,
    error: Color(0xFFFF6B6B),
  );

  static ThemeData darkTheme() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: darkScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: darkScheme.background,
      appBarTheme: AppBarTheme(
        backgroundColor: darkScheme.surface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: darkScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: darkScheme.onSurface),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkScheme.surface,
        selectedItemColor: darkScheme.primary,
        unselectedItemColor: darkScheme.onSurface.withOpacity(0.7),
        showSelectedLabels: true,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: darkScheme.primary,
        foregroundColor: darkScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 8,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkScheme.primary,
          foregroundColor: darkScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          elevation: 4,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkScheme.onSurface,
        ),
      ),
      cardTheme: CardTheme(
        color: Color(0xFF17171A),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF0E0E10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      pageTransitionsTheme: PageTransitionsTheme(builders: {
        TargetPlatform.android: _SmoothPageTransitionsBuilder(),
        TargetPlatform.iOS: _SmoothPageTransitionsBuilder(),
        TargetPlatform.macOS: _SmoothPageTransitionsBuilder(),
        TargetPlatform.windows: _SmoothPageTransitionsBuilder(),
        TargetPlatform.linux: _SmoothPageTransitionsBuilder(),
      }),
    );
  }
}

/// Custom page transition builder for smooth fade + slide transitions.
class _SmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const _SmoothPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
      PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    // Fade + slightly upward slide
    final opacity = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    final offset = Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: opacity,
      child: SlideTransition(position: offset, child: child),
    );
  }
}
