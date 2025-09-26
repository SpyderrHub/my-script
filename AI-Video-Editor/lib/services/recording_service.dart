// recording_service.dart
import 'dart:io';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'media_service.dart';

/// RecordingService: uses audio_waveforms RecorderController for live recording with waveform.
/// - startRecording returns a RecorderController that the UI can use for visualization.
/// - stopRecording finalizes file and returns recorded path.
class RecordingService {
  final _media = MediaService();
  final _uuid = const Uuid();

  Future<bool> _ensurePermissions() async {
    final micStatus = await Permission.microphone.request();
    return micStatus.isGranted;
  }

  /// Create a recorder controller prepared to record to an output file path.
  /// The caller should call start() on the returned controller and later stop().
  Future<RecorderController?> createRecorderController() async {
    final ok = await _ensurePermissions();
    if (!ok) return null;

    final controller = RecorderController()
      ..androidEncoder = AndroidEncoder.aac
      ..androidOutputFormat = AndroidOutputFormat.mpeg_4
      ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
      ..sampleRate = 44100
      ..bitRate = 128000;

    return controller;
  }

  /// Start a recording; returns the file path being recorded to (in app documents)
  Future<String> startRecording(RecorderController controller) async {
    final outPath = await _media.outputPathFor('voiceover_${_uuid.v4()}', 'm4a');
    // audio_waveforms uses start(path: ...) API
    await controller.record(path: outPath);
    return outPath;
  }

  /// Stop recording; returns the recorded file path (already returned by startRecording).
  Future<void> stopRecording(RecorderController controller) async {
    await controller.stop();
  }
}
