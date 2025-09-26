import 'dart:async';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../state/editor_state.dart';
import '../state/audio_models.dart';
import 'media_service.dart';
import 'audio_service.dart';
import 'package:flutter/foundation.dart';

class ExportResult {
  final String path;
  final int width;
  final int height;
  ExportResult({required this.path, required this.width, required this.height});
}

enum ExportResolution { r480p, r720p, r1080p, r4k }

class ExportService {
  final MediaService _media = MediaService();
  final AudioService _audio = AudioService();
  final _uuid = const Uuid();

  // map resolution enum to width/height
  Map<ExportResolution, List<int>> _resolutionMap = {
    ExportResolution.r480p: [854, 480],
    ExportResolution.r720p: [1280, 720],
    ExportResolution.r1080p: [1920, 1080],
    ExportResolution.r4k: [3840, 2160],
  };

  // Public entry: export project with editorModel and audio tracks to chosen resolution.
  // Returns ExportResult with final file path.
  Future<ExportResult> exportProject({
    required EditorModel editor,
    required List<AudioTrackModel> audioTracks,
    ExportResolution resolution = ExportResolution.r1080p,
    void Function(String)? onLog,
  }) async {
    if (editor.clips.isEmpty) {
      throw Exception('No clips to export');
    }

    final res = _resolutionMap[resolution]!;
    final width = res[0];
    final height = res[1];

    // 1) Normalize each clip to the target resolution and consistent codecs
    onLog?.call('Normalizing ${editor.clips.length} clips to ${width}x$height...');
    final List<String> normalizedClips = [];
    for (var clip in editor.clips) {
      final tmp = await _normalizeClip(clip.path, width, height, onLog: onLog);
      normalizedClips.add(tmp);
    }

    // 2) Concat normalized clips into a single video (tmp_concat.mp4)
    onLog?.call('Concatenating clips...');
    final concatPath = await _concatClips(normalizedClips, onLog: onLog);

    // 3) Prepare audio: process user audio tracks (volume/fades/trim already supported by AudioService)
    onLog?.call('Processing audio tracks...');
    final processedAudioPaths = <String>[];
    for (final at in audioTracks) {
      // If audio track has fades/volume different from defaults, create processed version
      // (this will re-encode audio). For efficiency, AudioService might skip if no change.
      final processed = await _audio.applyVolumeAndFades(
        at.path,
        volume: at.volume,
        fadeInMs: at.fadeInMs,
        fadeOutMs: at.fadeOutMs,
      );
      // apply timeline offset via adelay later
      processedAudioPaths.add(processed);
    }

    // 4) Mix audio: take concatPath's audio and user tracks with offsets into final mixed audio
    onLog?.call('Mixing audio tracks...');
    final mixedAudio = await _mixAudio(
      baseVideoPath: concatPath,
      audioTracks: audioTracks,
      processedAudioPaths: processedAudioPaths,
      onLog: onLog,
    );

    // 5) Mux video (from concatPath) with mixedAudio into final file
    onLog?.call('Muxing final output...');
    final finalOut = await _muxVideoAndAudio(concatPath, mixedAudio, width, height, onLog: onLog);

    onLog?.call('Export finished: $finalOut');
    return ExportResult(path: finalOut, width: width, height: height);
  }

  // Normalize a clip to the chosen resolution and common codec.
  // Returns path to normalized clip.
  Future<String> _normalizeClip(String inputPath, int width, int height, {void Function(String)? onLog}) async {
    final ext = _getExtension(inputPath) ?? 'mp4';
    final outPath = await _media.outputPathFor('norm_${_uuid.v4()}', ext);

    // scale & pad to exact resolution while preserving aspect ratio
    final vf =
        "scale='min(iw,${width})':'min(ih,${height})':force_original_aspect_ratio=decrease,pad=${width}:${height}:(ow-iw)/2:(oh-ih)/2,setsar=1,format=yuv420p";

    final cmd =
        '-i "${inputPath}" -vf "$vf" -c:v libx264 -preset veryfast -crf 23 -c:a aac -b:a 128k -movflags +faststart -y "${outPath}"';

    onLog?.call('FFmpeg normalize: $cmd');
    final session = await FFmpegKit.execute(cmd);
    final rc = await session.getReturnCode();
    if (ReturnCode.isSuccess(rc)) {
      return outPath;
    } else {
      final logs = await session.getAllLogsAsString();
      throw Exception('FFmpeg normalize failed: rc=$rc logs=$logs');
    }
  }

  // Concat using concat demuxer (requires files to have same codecs)
  Future<String> _concatClips(List<String> normalizedClips, {void Function(String)? onLog}) async {
    final listPath = await _media.outputPathFor('concat_list_${_uuid.v4()}', 'txt');
    final file = File(listPath);
    final sb = StringBuffer();
    for (final p in normalizedClips) {
      // escape single quotes by replacing ' with '"'"' to be safe in shell contexts (FFmpeg sees file)
      sb.writeln("file '${p.replaceAll("'", "%27")}'");
    }
    await file.writeAsString(sb.toString());

    final outPath = await _media.outputPathFor('concat_out_${_uuid.v4()}', 'mp4');

    // Use -safe 0 to allow absolute paths
    final cmd = '-f concat -safe 0 -i "${listPath}" -c copy -movflags +faststart -y "${outPath}"';

    onLog?.call('FFmpeg concat: $cmd');
    final session = await FFmpegKit.execute(cmd);
    final rc = await session.getReturnCode();
    if (ReturnCode.isSuccess(rc)) {
      return outPath;
    } else {
      // fallback: try filter_complex concat (re-encode)
      onLog?.call('Concat copy failed, trying filter_complex concat fallback...');
      final fallback = await _concatFallback(normalizedClips, onLog: onLog);
      return fallback;
    }
  }

  // Fallback concat using filter_complex (re-encode)
  Future<String> _concatFallback(List<String> normalizedClips, {void Function(String)? onLog}) async {
    final outPath = await _media.outputPathFor('concat_fallback_${_uuid.v4()}', 'mp4');

    final inputs = normalizedClips.map((p) => '-i "${p}"').join(' ');
    final n = normalizedClips.length;
    // build filter_complex [0:v:0][0:a:0][1:v:0][1:a:0]... concat=n:v=1:a=1 [v][a]
    final buffer = StringBuffer();
    for (var i = 0; i < n; i++) {
      buffer.write('[$i:v:0][$i:a:0]');
    }
    buffer.write('concat=n=$n:v=1:a=1[v][a]');

    final cmd = '$inputs -filter_complex "${buffer.toString()}" -map "[v]" -map "[a]" -c:v libx264 -preset veryfast -crf 23 -c:a aac -b:a 128k -movflags +faststart -y "${outPath}"';
    onLog?.call('FFmpeg concat fallback: $cmd');
    final session = await FFmpegKit.execute(cmd);
    final rc = await session.getReturnCode();
    if (ReturnCode.isSuccess(rc)) {
      return outPath;
    } else {
      final logs = await session.getAllLogsAsString();
      throw Exception('FFmpeg concat fallback failed: rc=$rc logs=$logs');
    }
  }

  // Mix audio tracks with the base video's audio (from concat video). Apply offsets via adelay and combine with amix.
  Future<String> _mixAudio({
    required String baseVideoPath,
    required List<AudioTrackModel> audioTracks,
    required List<String> processedAudioPaths,
    void Function(String)? onLog,
  }) async {
    final outPath = await _media.outputPathFor('mixed_audio_${_uuid.v4()}', 'm4a');

    // Build filter_complex:
    // inputs: 0 -> baseVideoPath (contains audio), 1..M -> processedAudioPaths
    // For each processed audio, apply adelay=<ms>|<ms> (for stereo) where ms is timelineOffsetMs
    // Finally amix inputs=(1+M) to mix base audio + all tracks
    // For safety, we'll re-encode audio to AAC at 192k

    // Build full ffmpeg command with inputs list
    final inputsSb = StringBuffer();
    inputsSb.write('-i "${baseVideoPath}" ');
    for (var i = 0; i < processedAudioPaths.length; i++) {
      inputsSb.write('-i "${processedAudioPaths[i]}" ');
    }

    // Build filter parts
    // label base audio as [a0], processed ones as [a1]..[aN] after adelay
    // We'll create [a0][a1d][a2d]... amix=inputs=K:duration=longest:dropout_transition=0 [outa]
    final filterSb = StringBuffer();
    // Map base audio
    filterSb.write('[0:a]aresample=48000[a0];');

    final amixInputs = <String>['[a0]'];
    for (var i = 0; i < audioTracks.length; i++) {
      final track = audioTracks[i];
      final procPath = processedAudioPaths.length > i ? processedAudioPaths[i] : track.path;
      final inputIndex = i + 1; // because 0 is baseVideoPath
      // adelay expects values per channel, e.g. adelay=1000|1000 for stereo, or single value for mono
      final delayMs = track.timelineOffsetMs;
      final adelayExpr = 'adelay=${delayMs}|${delayMs}';
      // apply adelay and resample
      filterSb.write('[$inputIndex:a]${adelayExpr},aresample=48000[a${i + 1}];');
      amixInputs.add('[a${i + 1}]');
    }

    final inputsCount = 1 + audioTracks.length;
    final amixInputsJoined = amixInputs.join('');
    filterSb.write('$amixInputsJoined' 'amix=inputs=$inputsCount:duration=longest:dropout_transition=0[outa]');

    final cmd = '${inputsSb.toString()} -filter_complex "${filterSb.toString()}" -map "[outa]" -c:a aac -b:a 192k -y "${outPath}"';

    onLog?.call('FFmpeg mix audio: $cmd');
    final session = await FFmpegKit.execute(cmd);
    final rc = await session.getReturnCode();
    if (ReturnCode.isSuccess(rc)) {
      return outPath;
    } else {
      final logs = await session.getAllLogsAsString();
      throw Exception('FFmpeg mix audio failed: rc=$rc logs=$logs');
    }
  }

  // Final mux: take video from concat and audio from mixedAudio and mux into final container
  Future<String> _muxVideoAndAudio(String videoPath, String audioPath, int width, int height, {void Function(String)? onLog}) async {
    final outPath = await _media.outputPathFor('final_export_${_uuid.v4()}', 'mp4');

    // Map video stream from videoPath and audio from audioPath; re-encode audio just in case
    final cmd =
        '-i "${videoPath}" -i "${audioPath}" -map 0:v -map 1:a -c:v copy -c:a aac -b:a 192k -movflags +faststart -y "${outPath}"';

    onLog?.call('FFmpeg mux: $cmd');
    final session = await FFmpegKit.execute(cmd);
    final rc = await session.getReturnCode();
    if (ReturnCode.isSuccess(rc)) {
      return outPath;
    } else {
      final logs = await session.getAllLogsAsString();
      throw Exception('FFmpeg mux failed: rc=$rc logs=$logs');
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
