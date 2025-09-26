import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai_video_editor/pages/home_page.dart';
import 'package:ai_video_editor/pages/edit_page.dart';
import 'package:ai_video_editor/pages/effects_page.dart';
import 'package:ai_video_editor/pages/export_page.dart';
import 'package:ai_video_editor/pages/profile_page.dart';
import 'package:ai_video_editor/widgets/bottom_nav.dart';

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

  static final List<Widget> _pages = <Widget>[
    const HomePage(),
    const EditPage(),
    const EffectsPage(),
    const ExportPage(),
    const ProfilePage(),
  ];

  void _onNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Video Editor',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: false,
      ),
      home: Scaffold(
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _pages[_selectedIndex],
          ),
        ),
        bottomNavigationBar: BottomNav(
          selectedIndex: _selectedIndex,
          onTap: _onNavTap,
        ),
      ),
    );
  }
}
