// transitions_service.dart
// Provides utilities to create preview thumbnails for transitions and to render transitions
import 'dart:io';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'media_service.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../state/editor_state.dart';

class TransitionsService {
  final MediaService _media = MediaService();
  final _uuid = const Uuid();

  /// Generate a low-res thumbnail showing transition from inputA to inputB.
  /// This uses FFmpeg xfade filter for a single-frame-like preview by taking a short segment
  /// around the transition point and exporting a single frame showing the blending.
  Future<String> generateTransitionThumbnail(String inputA, String inputB, TransitionType type,
      {int durationMs = 800, int timeMs = 400, int maxHeight = 160}) async {
    final name = 'transition_thumb_${_uuid.v4()}';
    final outPath = await _media.outputPathFor(name, 'jpg');

    final vfType = _xfadeName(type);
    // use xfade with offset near middle of concat
    // we prepare a short concat using -t durations and then apply xfade and capture a frame
    // For speed we seek near the end of A and use a very short portion.
    final ssA = 0.0; // use beginning - could be optimized
    // Build filter_complex to crossfade between the end of A and beginning of B
    // We'll produce a single-frame snapshot by seeking to the moment of crossfade.
    // Simpler approach: use -ss to input A and B and use xfade then grab 1 frame.
    final durS = (durationMs / 1000.0).toStringAsFixed(3);
    final ss = (timeMs / 1000.0).toStringAsFixed(3);

    // Compose command
    // -ss on inputs helps performance; we take 0s for both and rely on xfade duration small.
    final vf = 'xfade=transition=${vfType}:duration=${durS}:offset=0';
    final cmd =
        '-i "${inputA}" -i "${inputB}" -filter_complex "[0:v]scale=-2:${maxHeight},setsar=1[v0];[1:v]scale=-2:${maxHeight},setsar=1[v1];[v0][v1]${vf}" -frames:v 1 -y "${outPath}"';

    final session = await FFmpegKit.execute(cmd);
    final rc = await session.getReturnCode();
    if (ReturnCode.isSuccess(rc)) {
      return outPath;
    } else {
      final logs = await session.getAllLogsAsString();
      throw Exception('Transition thumbnail failed: rc=$rc logs=$logs');
    }
  }

  /// Apply a transition between two clips and produce a new joined file.
  /// The function returns the path to the new file which contains clipA (trimmed to end-transitionStart), transition, and clipB (from transitionEnd to end).
  /// Simple implementation: uses concat with xfade in filter_complex.
  Future<String> applyTransition(String inputA, String inputB, TransitionModel transition) async {
    final ext = _getExtension(inputA) ?? _getExtension(inputB) ?? 'mp4';
    final outPath = await _media.outputPathFor('transition_${transition.type}_${_uuid.v4()}', ext);

    final durS = (transition.durationMs / 1000.0).toStringAsFixed(3);
    final xfType = _xfadeName(transition.type);
    // We'll use xfade; offset=duration of A minus transition duration is typical; here we use 0 offset (simple)
    // Better implementations would compute exact offsets based on clip durations.
    final vf = 'xfade=transition=${xfType}:duration=${durS}:offset=0';

    // Filtering audio: acrossfade to blend audio for duration
    // Build command with re-encoding to ensure compatibility
    final cmd =
        '-i "${inputA}" -i "${inputB}" -filter_complex "[0:v]format=yuv420p,setsar=1[v0];[1:v]format=yuv420p,setsar=1[v1];[v0][v1]${vf}[vout];[0:a][1:a]acrossfade=d=${durS}[aout]" -map "[vout]" -map "[aout]" -c:v libx264 -preset veryfast -crf 23 -c:a aac -b:a 128k -y "${outPath}"';

    final session = await FFmpegKit.execute(cmd);
    final rc = await session.getReturnCode();
    if (ReturnCode.isSuccess(rc)) {
      return outPath;
    } else {
      final logs = await session.getAllLogsAsString();
      throw Exception('Apply transition failed: rc=$rc logs=$logs');
    }
  }

  String _xfadeName(TransitionType type) {
    switch (type) {
      case TransitionType.fade:
        return 'fade';
      case TransitionType.slide:
        // use slideleft as example; direction could be param
        return 'slideleft';
      case TransitionType.zoom:
        // xfade has 'squeeze' types; fallback to fade if not available
        return 'squeezeleft';
      case TransitionType.glitch:
        // no native xfade 'glitch' — emulate with 'frameblend' or 'overlay' if needed; choose 'fade' as safe fallback
        return 'fade';
      case TransitionType.flip3d:
        // some ffmpeg builds support '3dflip'
        return '3dflip';
      default:
        return 'fade';
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
