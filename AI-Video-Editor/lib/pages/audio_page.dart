// audio_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import '../state/providers_audio.dart';
import '../services/recording_service.dart';
import '../widgets/waveform_recorder.dart';
import '../state/audio_models.dart';

class AudioPage extends ConsumerStatefulWidget {
  const AudioPage({Key? key}) : super(key: key);

  @override
  ConsumerState<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends ConsumerState<AudioPage> {
  RecorderController? _recController;
  bool _isRecording = false;
  String? _currentRecordingPath;

  Future<void> _initRecorder() async {
    final recordingSvc = ref.read(recordingServiceProvider);
    final c = await recordingSvc.createRecorderController();
    if (c != null) {
      setState(() {
        _recController = c;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  @override
  void dispose() {
    _recController?.dispose();
    super.dispose();
  }

  Future<void> _importAudio() async {
    await ref.read(audioTracksProvider.notifier).importAudioFiles();
  }

  void _startRecording() async {
    if (_recController == null) {
      await _initRecorder();
    }
    final recordingSvc = ref.read(recordingServiceProvider);
    if (_recController == null) return;
    final path = await recordingSvc.startRecording(_recController!);
    setState(() {
      _isRecording = true;
      _currentRecordingPath = path;
    });
  }

  void _stopRecording() async {
    if (_recController == null) return;
    final recordingSvc = ref.read(recordingServiceProvider);
    await recordingSvc.stopRecording(_recController!);
    setState(() {
      _isRecording = false;
    });
    if (_currentRecordingPath != null) {
      // add as voiceover track aligned to 0 timeline offset (user can change)
      await ref.read(audioTracksProvider.notifier).addVoiceoverFromRecording(_currentRecordingPath!, timelineOffsetMs: 0);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Voiceover added to timeline')));
      _currentRecordingPath = null;
    }
  }

  Future<void> _showTrimDialog(AudioTrackModel t) async {
    int start = t.startMs;
    int end = t.endMs;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (_, setState) {
          return Padding(
            padding: MediaQuery.of(ctx).viewInsets,
            child: Container(
              padding: const EdgeInsets.all(16),
              height: 320,
              child: Column(
                children: [
                  Text('Trim audio (${(t.durationMs / 1000.0).toStringAsFixed(2)}s)'),
                  const SizedBox(height: 12),
                  Text('Start: ${(start / 1000.0).toStringAsFixed(2)}s'),
                  Slider(min: 0, max: t.durationMs.toDouble(), value: start.toDouble().clamp(0, t.durationMs.toDouble()), onChanged: (v) => setState(() => start = v.toInt())),
                  const SizedBox(height: 8),
                  Text('End: ${(end / 1000.0).toStringAsFixed(2)}s'),
                  Slider(min: 0, max: t.durationMs.toDouble(), value: end.toDouble().clamp(0, t.durationMs.toDouble()), onChanged: (v) => setState(() => end = v.toInt())),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel'))),
                      const SizedBox(width: 12),
                      Expanded(child: ElevatedButton(onPressed: start >= end ? null : () => Navigator.of(ctx).pop(true), child: const Text('Trim'))),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );

    if (result == true && start < end) {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      try {
        await ref.read(audioTracksProvider.notifier).cutTrack(t.id, start, end);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Trim failed: $e')));
      } finally {
        if (mounted) Navigator.of(context).pop();
      }
    }
  }

  Future<void> _showFadeDialog(AudioTrackModel t) async {
    int fadeIn = t.fadeInMs;
    int fadeOut = t.fadeOutMs;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (_, setState) {
          return Padding(
            padding: MediaQuery.of(ctx).viewInsets,
            child: Container(
              padding: const EdgeInsets.all(16),
              height: 260,
              child: Column(
                children: [
                  const Text('Fade In / Fade Out (ms)'),
                  const SizedBox(height: 12),
                  Text('Fade In: $fadeIn ms'),
                  Slider(min: 0, max: 5000, value: fadeIn.toDouble(), onChanged: (v) => setState(() => fadeIn = v.toInt())),
                  const SizedBox(height: 8),
                  Text('Fade Out: $fadeOut ms'),
                  Slider(min: 0, max: 5000, value: fadeOut.toDouble(), onChanged: (v) => setState(() => fadeOut = v.toInt())),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel'))),
                      const SizedBox(width: 12),
                      Expanded(child: ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Apply'))),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );

    if (result == true) {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      try {
        await ref.read(audioTracksProvider.notifier).setFades(t.id, fadeInMs: fadeIn, fadeOutMs: fadeOut);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Apply fades failed: $e')));
      } finally {
        if (mounted) Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracks = ref.watch(audioTracksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Audio')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                ElevatedButton.icon(onPressed: _importAudio, icon: const Icon(Icons.library_music), label: const Text('Import Music')),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                    onPressed: () {
                      if (_isRecording) return;
                      _startRecording();
                    },
                    icon: const Icon(Icons.mic),
                    label: const Text('Record Voiceover')),
                const SizedBox(width: 8),
                ElevatedButton.icon(onPressed: _isRecording ? _stopRecording : null, icon: const Icon(Icons.stop), label: const Text('Stop Recording')),
              ],
            ),
            const SizedBox(height: 12),
            if (_recController != null)
              WaveformRecorder(
                controller: _recController!,
                isRecording: _isRecording,
                onStartPressed: () {
                  setState(() {
                    _isRecording = true;
                  });
                  _startRecording();
                },
                onStopPressed: () {
                  setState(() {
                    _isRecording = false;
                  });
                  _stopRecording();
                },
              ),
            const SizedBox(height: 12),
            const Text('Tracks on Timeline', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: tracks.length,
                itemBuilder: (context, i) {
                  final t = tracks[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: t.isVoiceover ? const Icon(Icons.mic) : const Icon(Icons.audiotrack),
                      title: Text(File(t.path).uri.pathSegments.last),
                      subtitle: Text('Dur: ${(t.durationMs / 1000.0).toStringAsFixed(2)}s • Start at ${t.timelineOffsetMs}ms'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (val) async {
                          if (val == 'trim') await _showTrimDialog(t);
                          if (val == 'fade') await _showFadeDialog(t);
                          if (val == 'volume') {
                            final vol = await showDialog<double>(
                              context: context,
                              builder: (ctx) {
                                double v = t.volume;
                                return AlertDialog(
                                  title: const Text('Volume'),
                                  content: StatefulBuilder(builder: (_, setState) {
                                    return Slider(min: 0, max: 2.0, value: v, onChanged: (vv) => setState(() => v = vv));
                                  }),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
                                    ElevatedButton(onPressed: () => Navigator.of(ctx).pop(v), child: const Text('Apply')),
                                  ],
                                );
                              },
                            );
                            if (vol != null) {
                              showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                              try {
                                await ref.read(audioTracksProvider.notifier).setVolume(t.id, vol);
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Set volume failed: $e')));
                              } finally {
                                if (mounted) Navigator.of(context).pop();
                              }
                            }
                          }
                          if (val == 'offset') {
                            final offset = await showDialog<int>(
                              context: context,
                              builder: (ctx) {
                                int ofs = t.timelineOffsetMs;
                                return AlertDialog(
                                  title: const Text('Timeline Start Offset (ms)'),
                                  content: StatefulBuilder(builder: (_, setState) {
                                    return Slider(min: 0, max: 60000, value: ofs.toDouble().clamp(0, 60000), onChanged: (v) => setState(() => ofs = v.toInt()));
                                  }),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
                                    ElevatedButton(onPressed: () => Navigator.of(ctx).pop(ofs), child: const Text('Apply')),
                                  ],
                                );
                              },
                            );
                            if (offset != null) {
                              ref.read(audioTracksProvider.notifier).setTimelineOffset(t.id, offset);
                            }
                          }
                          if (val == 'delete') {
                            ref.read(audioTracksProvider.notifier).removeTrack(t.id);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'trim', child: Text('Trim/Cut')),
                          const PopupMenuItem(value: 'fade', child: Text('Fade In/Out')),
                          const PopupMenuItem(value: 'volume', child: Text('Adjust Volume')),
                          const PopupMenuItem(value: 'offset', child: Text('Set Timeline Offset')),
                          const PopupMenuItem(value: 'delete', child: Text('Remove')),
                        ],
                      ),
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
