import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai_video_editor/state/providers.dart';

class EffectsPage extends ConsumerWidget {
  const EffectsPage({Key? key}) : super(key: key);

  final List<String> availableEffects = const [
    'Speed Up',
    'Slow Motion',
    'Black & White',
    'Blur',
    'Text Overlay',
    'Auto Color Grade',
    'Stabilize',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.watch(editorProvider);
    final notifier = ref.read(editorProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Effects')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text('Add effects to clips — Current: ${editor.effects.length}', style: const TextStyle(fontSize: 16)),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: availableEffects.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, i) {
                final effect = availableEffects[i];
                final applied = editor.effects.contains(effect);
                return ListTile(
                  title: Text(effect),
                  trailing: IconButton(
                    icon: Icon(applied ? Icons.check_circle : Icons.add_circle_outline, color: applied ? Colors.green : null),
                    onPressed: () {
                      if (applied) {
                        notifier.removeEffect(effect);
                      } else {
                        notifier.addEffect(effect);
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
