import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../services/export_service.dart';
import '../state/providers.dart';
import '../state/providers_audio.dart';
import '../state/editor_state.dart';
import '../state/audio_models.dart';

class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({Key? key}) : super(key: key);

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  ExportResolution _selectedRes = ExportResolution.r1080p;
  bool _isExporting = false;
  String? _statusText;
  String? _exportedPath;

  Future<void> _startExport() async {
    setState(() {
      _isExporting = true;
      _statusText = 'Preparing export...';
      _exportedPath = null;
    });

    final editor = ref.read(editorProvider);
    final audioTracks = ref.read(audioTracksProvider);
    final exporter = ExportService();

    try {
      final result = await exporter.exportProject(
        editor: editor,
        audioTracks: audioTracks,
        resolution: _selectedRes,
        onLog: (s) {
          // append status logs (short)
          setState(() {
            _statusText = s;
          });
        },
      );
      setState(() {
        _isExporting = false;
        _exportedPath = result.path;
        _statusText = 'Export complete: ${result.path}';
      });
    } catch (e) {
      setState(() {
        _isExporting = false;
        _statusText = 'Export failed: $e';
      });
    }
  }

  // Share helpers (uses share_plus). On mobile this opens share sheet allowing user to select app.
  Future<void> _shareToPlatform(String platform) async {
    if (_exportedPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No exported video to share')));
      return;
    }
    final file = File(_exportedPath!);
    if (!await file.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exported file missing')));
      return;
    }

    final subject = {
      'instagram': 'Sharing to Instagram',
      'tiktok': 'Sharing to TikTok',
      'youtube': 'Sharing to YouTube',
    }[platform]!;
    final text = {
      'instagram': 'Check out my edit! #AIEditor',
      'tiktok': 'My edit using AI Video Editor! #fyp',
      'youtube': 'New video created with AI Video Editor',
    }[platform]!;

    // share_plus will show the platform chooser; direct-to-app upload is platform-specific and may require Intents or SDKs.
    try {
      await Share.shareXFiles([XFile(_exportedPath!)], text: text, subject: subject);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Share sheet opened')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Share failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final editor = ref.watch(editorProvider);
    final audioTracks = ref.watch(audioTracksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Export')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text('Clips: ${editor.clips.length}  •  Audio tracks: ${audioTracks.length}'),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Resolution: ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                DropdownButton<ExportResolution>(
                  value: _selectedRes,
                  items: const [
                    DropdownMenuItem(value: ExportResolution.r480p, child: Text('480p')),
                    DropdownMenuItem(value: ExportResolution.r720p, child: Text('720p')),
                    DropdownMenuItem(value: ExportResolution.r1080p, child: Text('1080p')),
                    DropdownMenuItem(value: ExportResolution.r4k, child: Text('4K')),
                  ],
                  onChanged: _isExporting ? null : (v) => setState(() => _selectedRes = v!),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _isExporting ? null : _startExport,
                  icon: const Icon(Icons.upload),
                  label: Text(_isExporting ? 'Exporting...' : 'Export & Encode'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_statusText != null) Text(_statusText!),
            const SizedBox(height: 12),
            if (_exportedPath != null)
              Column(
                children: [
                  Text('Exported: ${_exportedPath!}'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _shareToPlatform('instagram'),
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('Share to Instagram'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _shareToPlatform('tiktok'),
                        icon: const Icon(Icons.music_note),
                        label: const Text('Share to TikTok'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _shareToPlatform('youtube'),
                        icon: const Icon(Icons.ondemand_video),
                        label: const Text('Share to YouTube'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          // Generic share
                          try {
                            await Share.shareXFiles([XFile(_exportedPath!)], text: 'My edit from AI Video Editor');
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Share failed: $e')));
                          }
                        },
                        icon: const Icon(Icons.share),
                        label: const Text('Open Share Sheet'),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
