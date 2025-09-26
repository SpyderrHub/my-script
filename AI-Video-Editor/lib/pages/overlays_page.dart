// overlays_page.dart
// UI to add stickers/gifs/images/text overlays to clips. Uses file picker for stickers/GIFs and a text editor for text overlays.
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../state/providers.dart';
import '../state/editor_state.dart';

class OverlaysPage extends ConsumerStatefulWidget {
  const OverlaysPage({Key? key}) : super(key: key);

  @override
  ConsumerState<OverlaysPage> createState() => _OverlaysPageState();
}

class _OverlaysPageState extends ConsumerState<OverlaysPage> {
  String? _selectedClipId;
  final _uuid = const Uuid();

  Future<void> _pickStickerAndApply() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path!;
    await _createOverlayFromFile(path, OverlayType.sticker);
  }

  Future<void> _pickGifAndApply() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['gif']);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path!;
    await _createOverlayFromFile(path, OverlayType.gif);
  }

  Future<void> _createOverlayFromFile(String path, OverlayType type) async {
    if (_selectedClipId == null) {
      await _chooseClipThenApply((_) => _createOverlayFromFile(path, type));
      return;
    }

    // default positioned center
    final overlay = OverlayModel(
      id: _uuid.v4(),
      type: type,
      sourcePath: path,
      x: 0.35,
      y: 0.35,
      width: 0.3,
      height: 0.2,
      startMs: 0,
      endMs: 60000, // 1 min by default; clip duration will clamp
    );

    // Ask whether to bake now or keep editable
    final bake = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apply overlay'),
        content: const Text('Bake overlay into clip now? (baked overlay cannot be removed easily)'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Yes, Bake')),
        ],
      ),
    );

    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      await ref.read(editorProvider.notifier).addOverlayToClip(_selectedClipId!, overlay, bakeNow: bake == true);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Overlay added')));
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add overlay: $e')));
      }
    }
  }

  Future<void> _addTextOverlay() async {
    if (_selectedClipId == null) {
      await _chooseClipThenApply((_) => _addTextOverlay());
      return;
    }

    final textController = TextEditingController(text: 'Hello');
    final fontSizeController = TextEditingController(text: '36');
    String? fontPath; // optional file picker could be added
    final color = '#FFFFFF';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add Text Overlay'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: textController, decoration: const InputDecoration(labelText: 'Text')),
              TextField(controller: fontSizeController, decoration: const InputDecoration(labelText: 'Font size')),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  // optional font picker
                  final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['ttf', 'otf']);
                  if (res != null && res.files.isNotEmpty) {
                    fontPath = res.files.first.path;
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Font picked')));
                  }
                },
                child: const Text('Pick Font (optional)'),
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Add')),
          ],
        );
      },
    );

    if (result != true) return;

    final textStyle = TextStyleModel(
      text: textController.text,
      fontFile: fontPath,
      fontSize: double.tryParse(fontSizeController.text) ?? 36.0,
      colorHex: color,
      bold: false,
      italic: false,
      rotate: 0.0,
      animation: 'fade',
    );

    final overlay = OverlayModel(
      id: _uuid.v4(),
      type: OverlayType.text,
      sourcePath: textStyle.text, // text placed here
      x: 0.1,
      y: 0.1,
      width: 0.8,
      height: 0.2,
      startMs: 0,
      endMs: 60000,
      textStyle: textStyle,
    );

    final bake = true; // recommend baking text into video to avoid font issues on export
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      await ref.read(editorProvider.notifier).addOverlayToClip(_selectedClipId!, overlay, bakeNow: bake);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Text overlay added')));
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add text overlay: $e')));
      }
    }
  }

  Future<void> _chooseClipThenApply(Future<void> Function(String?) callback) async {
    final editor = ref.read(editorProvider);
    final clipId = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('Choose clip')),
              ...editor.clips.map((c) {
                return ListTile(
                  leading: c.thumbnailPath != null ? Image.file(File(c.thumbnailPath!), width: 56, height: 40, fit: BoxFit.cover) : const Icon(Icons.videocam),
                  title: Text(File(c.path).uri.pathSegments.last),
                  onTap: () => Navigator.of(ctx).pop(c.id),
                );
              }).toList(),
              ListTile(leading: const Icon(Icons.cancel), title: const Text('Cancel'), onTap: () => Navigator.of(ctx).pop(null)),
            ],
          ),
        );
      },
    );

    if (clipId == null) return;
    setState(() => _selectedClipId = clipId);
    await callback(clipId);
  }

  @override
  Widget build(BuildContext context) {
    final editor = ref.watch(editorProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Overlays')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Text('Add stickers, GIFs, images or custom text onto clips'),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(onPressed: _pickStickerAndApply, icon: const Icon(Icons.emoji_emotions), label: const Text('Add Sticker')),
                const SizedBox(width: 8),
                ElevatedButton.icon(onPressed: _pickGifAndApply, icon: const Icon(Icons.gif), label: const Text('Add GIF')),
                const SizedBox(width: 8),
                ElevatedButton.icon(onPressed: _addTextOverlay, icon: const Icon(Icons.text_fields), label: const Text('Add Text')),
                const Spacer(),
                Text('Selected: ${editor.clips.indexWhere((c) => c.id == _selectedClipId) >= 0 ? (editor.clips.indexWhere((c) => c.id == _selectedClipId) + 1) : 'None'}'),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: () => _chooseClipThenApply((_) {}), child: const Text('Choose Clip')),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: editor.clips.length,
                itemBuilder: (context, i) {
                  final c = editor.clips[i];
                  return ListTile(
                    leading: c.thumbnailPath != null ? Image.file(File(c.thumbnailPath!), width: 80, height: 56, fit: BoxFit.cover) : const Icon(Icons.videocam),
                    title: Text(File(c.path).uri.pathSegments.last),
                    subtitle: Text('Overlays: ${c.overlays.length}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.play_arrow),
                      onPressed: () {
                        setState(() {
                          _selectedClipId = c.id;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clip selected')));
                      },
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
}
