import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../state/providers.dart';
import '../widgets/timeline_item.dart';
import '../state/editor_state.dart';

class EditPage extends ConsumerStatefulWidget {
  const EditPage({Key? key}) : super(key: key);

  @override
  ConsumerState<EditPage> createState() => _EditPageState();
}

class _EditPageState extends ConsumerState<EditPage> {
  VideoPlayerController? _previewController;
  String? _selectedClipId;

  @override
  void dispose() {
    _previewController?.dispose();
    super.dispose();
  }

  Future<void> _playClip(ClipModel clip) async {
    _previewController?.dispose();
    _previewController = VideoPlayerController.file(File(clip.path));
    await _previewController!.initialize();
    // If clip is trimmed (start !=0 or end != duration), we rely on ffmpeg outputs being separate files.
    _previewController!.setLooping(true);
    setState(() {
      _selectedClipId = clip.id;
    });
    _previewController!.play();
  }

  Future<void> _import() async {
    await ref.read(editorProvider.notifier).importFiles();
  }

  // Show a trimming UI (two sliders). For simplicity, sliders operate on 0..durationMs.
  Future<void> _showTrimSheet(ClipModel clip) async {
    int start = clip.startMs;
    int end = clip.endMs;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx2, setState) {
          return Padding(
            padding: MediaQuery.of(ctx).viewInsets,
            child: Container(
              padding: const EdgeInsets.all(16),
              height: 300,
              child: Column(
                children: [
                  Text('Trim clip (${Duration(milliseconds: clip.durationMs)})'),
                  const SizedBox(height: 12),
                  Text('Start: ${(start / 1000).toStringAsFixed(2)}s'),
                  Slider(
                    min: 0,
                    max: clip.durationMs.toDouble(),
                    value: start.toDouble().clamp(0, clip.durationMs.toDouble()),
                    onChanged: (v) => setState(() => start = v.toInt()),
                  ),
                  Text('End: ${(end / 1000).toStringAsFixed(2)}s'),
                  Slider(
                    min: 0,
                    max: clip.durationMs.toDouble(),
                    value: end.toDouble().clamp(0, clip.durationMs.toDouble()),
                    onChanged: (v) => setState(() => end = v.toInt()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: start >= end ? null : () => Navigator.of(ctx).pop(true),
                          child: const Text('Trim'),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        });
      },
    );

    if (result == true && start < end) {
      // Convert start/end (relative to clip) into absolute ms for ffmpeg trim
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      try {
        await ref.read(editorProvider.notifier).trimClip(clip.id, start, end);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Trim failed: $e')));
      } finally {
        if (mounted) Navigator.of(context).pop(); // close loading dialog
      }
    }
  }

  Future<void> _splitClip(ClipModel clip) async {
    // Ask user for a split time (simple dialog)
    final timeStr = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Split at (seconds)'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'e.g. 2.5'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(controller.text), child: const Text('Split')),
          ],
        );
      },
    );

    if (timeStr == null || timeStr.isEmpty) return;
    final seconds = double.tryParse(timeStr);
    if (seconds == null) return;
    final ms = (seconds * 1000).toInt();
    if (ms <= 0 || ms >= clip.durationMs) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid split time')));
      return;
    }

    // Show loading
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await ref.read(editorProvider.notifier).splitClip(clip.id, ms);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Split failed: $e')));
    } finally {
      if (mounted) Navigator.of(context).pop(); // close loading dialog
    }
  }

  @override
  Widget build(BuildContext context) {
    final editor = ref.watch(editorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit'),
        actions: [
          IconButton(onPressed: _import, icon: const Icon(Icons.file_upload)),
        ],
      ),
      body: Column(
        children: [
          // Preview
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: _previewController == null
                  ? const Center(child: Text('Select a clip to preview', style: TextStyle(color: Colors.white)))
                  : VideoPlayer(_previewController!),
            ),
          ),
          // Timeline (reorderable)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                const Text('Timeline', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('Clips: ${editor.clips.length}'),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              onReorder: (oldIndex, newIndex) => ref.read(editorProvider.notifier).reorderClips(oldIndex, newIndex),
              itemCount: editor.clips.length,
              buildDefaultDragHandles: true,
              itemBuilder: (context, index) {
                final clip = editor.clips[index];
                return TimelineItem(
                  key: ValueKey(clip.id),
                  clip: clip,
                  onTap: () => _playClip(clip),
                  onTrim: () => _showTrimSheet(clip),
                  onSplit: () => _splitClip(clip),
                  onDelete: () => ref.read(editorProvider.notifier).removeClipById(clip.id),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Quick export to test (not full export flow)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export pipeline to implement...')));
        },
        icon: const Icon(Icons.save_alt),
        label: const Text('Export'),
      ),
    );
  }
}
