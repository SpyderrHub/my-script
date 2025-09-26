import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai_video_editor/state/providers.dart';
import 'package:ai_video_editor/services/video_service.dart';

class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({Key? key}) : super(key: key);

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  bool _isExporting = false;
  String? _statusText;
  String? _downloadUrl;

  Future<void> _export() async {
    setState(() {
      _isExporting = true;
      _statusText = 'Starting export...';
      _downloadUrl = null;
    });

    final editor = ref.read(editorProvider);
    final service = VideoService();

    try {
      final job = await service.createExportJob(editor);
      setState(() {
        _statusText = 'Export queued. Job id: ${job['jobId']}';
      });

      // Poll for job (simplified); in production use webhooks or status endpoint
      final result = await service.pollExportJob(job['jobId']);
      setState(() {
        _isExporting = false;
        _statusText = 'Export completed';
        _downloadUrl = result['downloadUrl'];
      });
    } catch (e) {
      setState(() {
        _isExporting = false;
        _statusText = 'Export failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editor = ref.watch(editorProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Export')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text('Clips: ${editor.clips.length}, Effects: ${editor.effects.length}'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isExporting ? null : _export,
              icon: const Icon(Icons.upload),
              label: Text(_isExporting ? 'Exporting...' : 'Export Project'),
            ),
            const SizedBox(height: 16),
            if (_statusText != null) Text(_statusText!),
            const SizedBox(height: 12),
            if (_downloadUrl != null)
              SelectableText('Download: $_downloadUrl', style: const TextStyle(color: Colors.blue)),
          ],
        ),
      ),
    );
  }
}
