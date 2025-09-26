// transitions_page.dart
// UI for browsing transitions, preview thumbnails and applying a transition between two selected clips.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/transitions_service.dart';
import '../state/providers.dart';
import '../state/editor_state.dart';

class TransitionsPage extends ConsumerStatefulWidget {
  const TransitionsPage({Key? key}) : super(key: key);

  @override
  ConsumerState<TransitionsPage> createState() => _TransitionsPageState();
}

class _TransitionsPageState extends ConsumerState<TransitionsPage> {
  final Map<TransitionType, String?> _thumbCache = {};
  final Map<TransitionType, bool> _isGenerating = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _generateThumbs();
  }

  Future<void> _generateThumbs() async {
    final editor = ref.read(editorProvider);
    if (editor.clips.length < 2) return;
    final svc = ref.read(transitionsServiceProvider);
    final a = editor.clips[0];
    final b = editor.clips[1];

    for (final t in TransitionType.values) {
      if (_thumbCache.containsKey(t)) continue;
      _isGenerating[t] = true;
      setState(() {});
      try {
        final thumb = await svc.generateTransitionThumbnail(a.path, b.path, t);
        _thumbCache[t] = thumb;
      } catch (e) {
        _thumbCache[t] = a.thumbnailPath;
      } finally {
        _isGenerating[t] = false;
        if (mounted) setState(() {});
      }
    }
  }

  Future<void> _applyTransitionToIndex(TransitionType type, int index) async {
    // confirm clips exist
    final editor = ref.read(editorProvider);
    if (index < 0 || index >= editor.clips.length - 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid index for transition')));
      return;
    }

    // pick duration (basic)
    final durationMs = await showDialog<int>(
      context: context,
      builder: (ctx) {
        int ms = 800;
        return AlertDialog(
          title: const Text('Transition duration (ms)'),
          content: StatefulBuilder(builder: (ctx2, setState) {
            return Slider(
              min: 200,
              max: 2000,
              value: ms.toDouble(),
              onChanged: (v) => setState(() => ms = v.toInt()),
              divisions: 18,
            );
          }),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(ms), child: const Text('Apply')),
          ],
        );
      },
    );

    if (durationMs == null) return;

    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      await ref.read(editorProvider.notifier).addTransitionAtIndex(index, type, durationMs);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transition applied and clips merged')));
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to apply transition: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final effects = TransitionType.values;
    final editor = ref.watch(editorProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Transitions')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Text('Transitions: select one to apply between two adjacent clips'),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                itemCount: effects.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.6, mainAxisSpacing: 8, crossAxisSpacing: 8),
                itemBuilder: (context, i) {
                  final type = effects[i];
                  final thumb = _thumbCache[type];
                  final isGen = _isGenerating[type] ?? false;
                  return Card(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Container(
                            color: Colors.black12,
                            child: isGen
                                ? const Center(child: CircularProgressIndicator())
                                : (thumb != null ? Image.file(File(thumb), fit: BoxFit.cover) : Center(child: Text(describeEnum(type)))),
                            height: double.infinity,
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(describeEnum(type), style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text(_subtitleFor(type)),
                                const Spacer(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    ElevatedButton(
                                      onPressed: editor.clips.length >= 2 ? () => _applyTransitionToIndex(type, 0) : null,
                                      child: const Text('Apply (between 0 & 1)'),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitleFor(TransitionType t) {
    switch (t) {
      case TransitionType.fade:
        return 'Cross-fade';
      case TransitionType.slide:
        return 'Slide (left)';
      case TransitionType.zoom:
        return 'Zoom blend';
      case TransitionType.glitch:
        return 'Digital glitch (emulated)';
      case TransitionType.flip3d:
        return '3D flip';
    }
  }
}
