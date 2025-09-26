import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai_video_editor/state/providers.dart';
import 'package:video_player/video_player.dart';

class EditPage extends ConsumerStatefulWidget {
  const EditPage({Key? key}) : super(key: key);

  @override
  ConsumerState<EditPage> createState() => _EditPageState();
}

class _EditPageState extends ConsumerState<EditPage> {
  VideoPlayerController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _playSample() async {
    // This is just a preview; in a real app load actual clip file paths
    _controller?.dispose();
    _controller = VideoPlayerController.network(
        'https://sample-videos.com/video123/mp4/720/big_buck_bunny_720p_1mb.mp4');
    await _controller!.initialize();
    _controller!.setLooping(true);
    setState(() {});
    _controller!.play();
  }

  @override
  Widget build(BuildContext context) {
    final editor = ref.watch(editorProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit')),
      body: Column(
        children: [
          // Preview area
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: _controller == null
                  ? Center(
                      child: TextButton.icon(
                        onPressed: _playSample,
                        icon: const Icon(Icons.play_arrow, color: Colors.white),
                        label: const Text('Play sample', style: TextStyle(color: Colors.white)),
                      ),
                    )
                  : VideoPlayer(_controller!),
            ),
          ),
          // Timeline / clips
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    ref.read(editorProvider.notifier).addClip('sample_clip_${DateTime.now().millisecondsSinceEpoch}.mp4');
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Clip'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    ref.read(editorProvider.notifier).undo();
                  },
                  icon: const Icon(Icons.undo),
                  label: const Text('Undo'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    ref.read(editorProvider.notifier).redo();
                  },
                  icon: const Icon(Icons.redo),
                  label: const Text('Redo'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: editor.clips.length,
              itemBuilder: (context, i) {
                final clip = editor.clips[i];
                return ListTile(
                  leading: const Icon(Icons.video_file),
                  title: Text(clip),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => ref.read(editorProvider.notifier).removeClip(clip),
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
