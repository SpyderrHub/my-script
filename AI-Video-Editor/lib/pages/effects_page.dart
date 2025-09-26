// effects_page.dart (REPLACE OR ADD)
// This UI shows all effects as thumbnails; tapping an effect opens a menu to preview (fast) or apply to a clip.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/effects_service.dart';
import '../state/providers.dart';
import '../state/editor_state.dart';

class EffectsPage extends ConsumerStatefulWidget {
  const EffectsPage({Key? key}) : super(key: key);

  @override
  ConsumerState<EffectsPage> createState() => _EffectsPageState();
}

class _EffectsPageState extends ConsumerState<EffectsPage> {
  final Map<EffectType, String?> _thumbCache = {};
  final Map<EffectType, bool> _isGenerating = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _generateThumbnailsForAvailableEffects();
  }

  Future<void> _generateThumbnailsForAvailableEffects() async {
    final editor = ref.read(editorProvider);
    if (editor.clips.isEmpty) return;
    final sample = editor.clips.first;
    final effectsSvc = ref.read(effectsServiceProvider);

    for (final entry in EffectsService.descriptors.entries) {
      final effect = entry.key;
      if (_thumbCache.containsKey(effect)) continue;
      _isGenerating[effect] = true;
      setState(() {});
      try {
        final thumb = await effectsSvc.generateEffectThumbnail(sample.path, effect, timeMs: 800);
        _thumbCache[effect] = thumb;
      } catch (e) {
        // fallback: use original clip thumbnail or null
        _thumbCache[effect] = sample.thumbnailPath;
      } finally {
        _isGenerating[effect] = false;
        if (mounted) setState(() {});
      }
    }
  }

  // Quick preview for color filters via ColorFiltered on VideoPlayer would be faster,
  // but here we provide a dialog that either plays the clip with a simple transform
  // (for color filters we can do local ColorFilter; heavier ones will be FFmpeg snapshot).
  void _showPreviewDialog(EffectType effect) {
    final desc = EffectsService.descriptors[effect]!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Preview: ${desc.name}'),
        content: SizedBox(
          width: 360,
          height: 240,
          child: Center(
            child: Text(
              'Preview generated as thumbnail (tap apply to process full clip).',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _applyEffect(EffectType effect) async {
    final editor = ref.read(editorProvider);
    if (editor.clips.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No clip to apply effect to')));
      return;
    }

    // Choose a clip to apply to (list of clips)
    final clipId = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('Choose clip to apply effect')),
              ...editor.clips.map((c) {
                return ListTile(
                  leading: c.thumbnailPath != null ? Image.file(File(c.thumbnailPath!), width: 56, height: 40, fit: BoxFit.cover) : const Icon(Icons.videocam),
                  title: Text(File(c.path).uri.pathSegments.last),
                  subtitle: Text('${(c.durationMs / 1000.0).toStringAsFixed(1)}s'),
                  onTap: () => Navigator.of(ctx).pop(c.id),
                );
              }).toList(),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('Cancel'),
                onTap: () => Navigator.of(ctx).pop(null),
              )
            ],
          ),
        );
      },
    );

    if (clipId == null) return;

    // Run apply and show progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await ref.read(editorProvider.notifier).applyEffectToClip(clipId, effect);
      if (mounted) {
        Navigator.of(context).pop(); // close progress
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Effect applied')));
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to apply effect: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final effects = EffectsService.descriptors.values.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Effects')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Text('Effects Gallery (tap thumbnail to preview, Apply to process clip)'),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                itemCount: effects.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.6, mainAxisSpacing: 8, crossAxisSpacing: 8),
                itemBuilder: (context, i) {
                  final desc = effects[i];
                  final thumb = _thumbCache[desc.type];
                  final isGen = _isGenerating[desc.type] ?? false;
                  return Card(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Container(
                            color: Colors.black12,
                            child: isGen
                                ? const Center(child: CircularProgressIndicator())
                                : (thumb != null
                                    ? Image.file(File(thumb), fit: BoxFit.cover)
                                    : Center(child: Text(desc.name))),
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
                                Text(desc.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text(_subtitleFor(desc.type)),
                                const Spacer(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      tooltip: 'Preview',
                                      onPressed: () => _showPreviewDialog(desc.type),
                                      icon: const Icon(Icons.visibility),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => _applyEffect(desc.type),
                                      child: const Text('Apply'),
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

  String _subtitleFor(EffectType type) {
    switch (type) {
      case EffectType.brightness:
      case EffectType.contrast:
      case EffectType.saturation:
      case EffectType.sepia:
      case EffectType.grayscale:
        return 'Color filter (fast preview)';
      case EffectType.slowMotion:
        return 'Slows playback 2x (audio adjusted)';
      case EffectType.reverse:
        return 'Plays clip backwards';
      case EffectType.zoom:
        return 'Animated zoom in';
      case EffectType.shake:
        return 'Camera shake effect';
      default:
        return '';
    }
  }
}
