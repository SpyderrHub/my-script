import 'dart:convert';
import 'package:ai_video_editor/state/editor_state.dart';
import 'package:http/http.dart' as http;

/// Simple video service to call backend export APIs.
/// Replace baseUrl with your server (for mobile simulator/emulator adjust host if needed).
class VideoService {
  // For real device testing, set an accessible host (ngrok, local network IP, or cloud)
  final String baseUrl;

  VideoService({String? baseUrl}) : baseUrl = baseUrl ?? 'http://10.0.2.2:4000';

  Future<Map<String, dynamic>> createExportJob(EditorModel editor) async {
    final url = Uri.parse('$baseUrl/api/export');
    final resp = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode(editor.toJson()));
    if (resp.statusCode != 200) {
      throw Exception('Failed to create export job: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  // Poll the job endpoint until finished (simplified demo)
  Future<Map<String, dynamic>> pollExportJob(String jobId, {int attempts = 10, Duration delay = const Duration(seconds: 1)}) async {
    final url = Uri.parse('$baseUrl/api/export/$jobId');
    for (var i = 0; i < attempts; i++) {
      final resp = await http.get(url);
      if (resp.statusCode != 200) {
        throw Exception('Failed to poll job: ${resp.body}');
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['status'] == 'done') {
        return data;
      }
      await Future.delayed(delay);
    }
    throw Exception('Export job timed out');
  }
}
