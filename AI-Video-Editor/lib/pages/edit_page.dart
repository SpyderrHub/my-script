import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/providers.dart';
import '../widgets/edit_fab.dart';
import '../widgets/swipeable_timeline.dart';
import '../widgets/rounded_button.dart';

class EditPage extends ConsumerStatefulWidget {
  const EditPage({Key? key}) : super(key: key);

  @override
  ConsumerState<EditPage> createState() => _EditPageState();
}

class _EditPageState extends ConsumerState<EditPage> {
  String? _selectedClipId;

  @override
  Widget build(BuildContext context) {
    final editor = ref.watch(editorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.undo)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.redo)),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Preview area (placeholder)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
              child: Center(
                child: _selectedClipId == null
                    ? Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.play_circle, size: 44, color: Colors.white54), const SizedBox(height: 8), Text('Select a clip to preview', style: TextStyle(color: Colors.white70))])
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(editor.clips.firstWhere((c) => c.id == _selectedClipId!).thumbnailPath ?? ''),
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
            ),
          ),
          // Swipeable timeline with smooth animations
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Text('Timeline', style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                RoundedButton(label: 'Add Media', icon: Icons.add, onPressed: () => ref.read(editorProvider.notifier).importFiles(), elevated: true),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Column(
                children: [
                  SwipeableTimeline(
                    clips: editor.clips,
                    selectedClipId: _selectedClipId,
                    onSelect: (clipId) => setState(() => _selectedClipId = clipId),
                    onReorder: (oldIndex, newIndex) => ref.read(editorProvider.notifier).reorderClips(oldIndex, newIndex),
                  ),
                  const SizedBox(height: 12),
                  // Quick action chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _actionChip(context, Icons.content_cut, 'Trim', () {}),
                        const SizedBox(width: 8),
                        _actionChip(context, Icons.call_split, 'Split', () {}),
                        const SizedBox(width: 8),
                        _actionChip(context, Icons.auto_awesome, 'Effects', () {}),
                        const SizedBox(width: 8),
                        _actionChip(context, Icons.transition, 'Transitions', () {}),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: EditFab(onAction: (a) {
        // wire mini actions
        if (a == 'trim') {
          // navigate to trim ui or open modal
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open trim UI')));
        } else if (a == 'split') {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open split UI')));
        } else if (a == 'effects') {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open effects UI')));
        }
      }),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _actionChip(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurface),
      label: Text(label),
      elevation: 2,
      backgroundColor: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
    );
  }
}
