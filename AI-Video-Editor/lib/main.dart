import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'pages/home_page.dart';
import 'pages/edit_page.dart';
import 'pages/effects_page.dart';
import 'pages/export_page.dart';
import 'pages/profile_page.dart';
import 'widgets/animated_bottom_nav.dart';

void main() {
  runApp(const ProviderScope(child: AiVideoEditorApp()));
}

class AiVideoEditorApp extends StatefulWidget {
  const AiVideoEditorApp({Key? key}) : super(key: key);

  @override
  State<AiVideoEditorApp> createState() => _AiVideoEditorAppState();
}

class _AiVideoEditorAppState extends State<AiVideoEditorApp> {
  int _selectedIndex = 0;
  final List<Widget> _pages = const [
    HomePage(),
    EditPage(),
    EffectsPage(),
    ExportPage(),
    ProfilePage(),
  ];

  void _onNavTap(int i) {
    setState(() {
      _selectedIndex = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Video Editor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme(),
      home: Scaffold(
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(anim), child: child)),
            child: _pages[_selectedIndex],
          ),
        ),
        bottomNavigationBar: AnimatedBottomNav(selectedIndex: _selectedIndex, onTap: _onNavTap),
      ),
    );
  }
}
