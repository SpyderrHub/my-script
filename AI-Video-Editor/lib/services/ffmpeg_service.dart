import 'dart:io';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'media_service.dart';

/// FfmpegService: trim and split using FFmpegKit.
/// This runs native ffmpeg on device. For large files this avoids loading entire file into memory.
/// Important: test on real device/emulator and adjust codecs/flags for your target devices.
class FfmpegService {
  final MediaService _media = MediaService();

  // Trim a region from inputPath [startMs, endMs) and returns the output path.
  Future<String> trimClip(String inputPath, int startMs, int endMs) async {
    final ext = _getExtension(inputPath) ?? 'mp4';
    final outPath = await _media.outputPathFor('trim', ext);

    final startS = (startMs / 1000.0).toStringAsFixed(3);
    final durationS = ((endMs - startMs) / 1000.0).toStringAsFixed(3);

    // We re-encode to avoid keyframe-only cut problems. For performance you may use -c copy depending on input.
    final command = '-ss $startS -i "${inputPath}" -t $durationS -c:v libx264 -preset ultrafast -crf 28 -c:a aac -b:a 128k -y "${outPath}"';

    final session = await FFmpegKit.execute(command);
    final rc = await session.getReturnCode();
    if (ReturnCode.isSuccess(rc)) {
      return outPath;
    } else {
      final logs = await session.getAllLogsAsString();
      throw Exception('FFmpeg trim failed: rc=$rc logs=$logs');
    }
  }

  // Split into two clips at splitMs (relative to original clip duration)
  // Returns [partAPath, partBPath]
  Future<List<String>> splitClip(String inputPath, int splitMs, int originalDurationMs) async {
    final ext = _getExtension(inputPath) ?? 'mp4';
    final outA = await _media.outputPathFor('split_a', ext);
    final outB = await _media.outputPathFor('split_b', ext);

    final splitS = (splitMs / 1000.0).toStringAsFixed(3);
    final durAS = splitS;
    final durBS = ((originalDurationMs - splitMs) / 1000.0).toStringAsFixed(3);

    final cmdA = '-ss 0 -i "${inputPath}" -t $durAS -c:v libx264 -preset ultrafast -crf 28 -c:a aac -b:a 128k -y "${outA}"';
    final sessionA = await FFmpegKit.execute(cmdA);
    final rcA = await sessionA.getReturnCode();
    if (!ReturnCode.isSuccess(rcA)) {
      final logs = await sessionA.getAllLogsAsString();
      throw Exception('FFmpeg split A failed: rc=$rcA logs=$logs');
    }

    final cmdB = '-ss $splitS -i "${inputPath}" -t $durBS -c:v libx264 -preset ultrafast -crf 28 -c:a aac -b:a 128k -y "${outB}"';
    final sessionB = await FFmpegKit.execute(cmdB);
    final rcB = await sessionB.getReturnCode();
    if (!ReturnCode.isSuccess(rcB)) {
      final logs = await sessionB.getAllLogsAsString();
      throw Exception('FFmpeg split B failed: rc=$rcB logs=$logs');
    }

    return [outA, outB];
  }

  String? _getExtension(String path) {
    final idx = path.lastIndexOf('.');
    if (idx < 0 || idx == path.length - 1) return null;
    return path.substring(idx + 1).toLowerCase();
  }
}
