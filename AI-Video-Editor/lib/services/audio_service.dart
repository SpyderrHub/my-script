// audio_service.dart
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'media_service.dart';

/// AudioService:
/// - import audio files (file picker)
/// - get duration via just_audio
/// - cut/trim audio with FFmpeg
/// - apply volume/fade in/out using FFmpeg audio filters
class AudioService {
  final MediaService _media = MediaService();
  final _uuid = const Uuid();

  Future<List<String>?> pickAudioFiles() async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.audio);
    if (res == null || res.paths.isEmpty) return null;
    return res.paths.whereType<String>().toList();
  }

  /// Get audio duration in ms using just_audio
  Future<int> getAudioDurationMs(String path) async {
    final player = AudioPlayer();
    try {
      await player.setFilePath(path);
      final dur = player.duration ?? Duration.zero;
      await player.dispose();
      return dur.inMilliseconds;
    } catch (e) {
      try {
        await player.dispose();
      } catch (_) {}
      return 0;
    }
  }

  /// Trim audio: keep range [startMs, endMs) (ms). Returns outPath.
  Future<String> trimAudio(String inputPath, int startMs, int endMs) async {
    final ext = _getExtension(inputPath) ?? 'mp3';
    final outPath = await _media.outputPathFor('audio_trim_${_uuid.v4()}', ext);

    final startS = (startMs / 1000.0).toStringAsFixed(3);
    final durationS = ((endMs - startMs) / 1000.0).toStringAsFixed(3);

    // Re-encode audio for compatibility
    final cmd = '-ss $startS -i "${inputPath}" -t $durationS -c:a aac -b:a 192k -y "${outPath}"';
    final session = await FFmpegKit.execute(cmd);
    final rc = await session.getReturnCode();
    if (ReturnCode.isSuccess(rc)) {
      return outPath;
    } else {
      final logs = await session.getAllLogsAsString();
      throw Exception('FFmpeg audio trim failed: rc=$rc logs=$logs');
    }
  }

  /// Apply volume and optional fade-in/out to audio and return new path.
  /// volume: linear scale (1.0 = normal)
  Future<String> applyVolumeAndFades(String inputPath,
      {double volume = 1.0, int fadeInMs = 0, int fadeOutMs = 0}) async {
    final ext = _getExtension(inputPath) ?? 'mp3';
    final outPath = await _media.outputPathFor('audio_volfade_${_uuid.v4()}', ext);

    final filters = <String>[];

    // Volume filter (volume accepts linear factor)
    if (volume != 1.0) {
      filters.add('volume=${volume.toStringAsFixed(3)}');
    }

    // Fade-in
    if (fadeInMs > 0) {
      final d = (fadeInMs / 1000.0).toStringAsFixed(3);
      filters.add('afade=t=in:st=0:d=$d');
    }

    // Fade-out (start at audio duration - fadeOutMs; we will try to compute duration using just_audio first)
    String? audioDurationS;
    if (fadeOutMs > 0) {
      final durMs = await getAudioDurationMs(inputPath);
      if (durMs > 0) {
        final start = ((durMs - fadeOutMs) / 1000.0).clamp(0.0, double.infinity).toStringAsFixed(3);
        final d = (fadeOutMs / 1000.0).toStringAsFixed(3);
        filters.add('afade=t=out:st=$start:d=$d');
      } else {
        // fallback: apply out fade starting at 0 (won't be ideal)
        final d = (fadeOutMs / 1000.0).toStringAsFixed(3);
        filters.add('afade=t=out:st=0:d=$d');
      }
    }

    final af = filters.isNotEmpty ? filters.join(',') : null;

    final cmd = af != null
        ? '-i "${inputPath}" -af "$af" -c:a aac -b:a 192k -y "${outPath}"'
        : '-i "${inputPath}" -c:a aac -b:a 192k -y "${outPath}"';

    final session = await FFmpegKit.execute(cmd);
    final rc = await session.getReturnCode();
    if (ReturnCode.isSuccess(rc)) {
      return outPath;
    } else {
      final logs = await session.getAllLogsAsString();
      throw Exception('FFmpeg applyVolumeAndFades failed: rc=$rc logs=$logs');
    }
  }

  String? _getExtension(String path) {
    try {
      final ext = p.extension(path);
      if (ext.isEmpty) return null;
      return ext.replaceFirst('.', '').toLowerCase();
    } catch (e) {
      return null;
    }
  }
}
