// effects_service.dart
import 'dart:io';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:path/path.dart' as p;
import 'media_service.dart';

enum EffectType {
  brightness,
  contrast,
  saturation,
  sepia,
  grayscale,
  slowMotion,
  reverse,
  zoom,
  shake,
}

/// Descriptor holds display name and an FFmpeg filter snippet (or a builder).
class EffectDescriptor {
  final EffectType type;
  final String name;
  final String Function()? ffmpegVideoFilter; // returns -vf string (may be null for complex commands)
  final String Function()? ffmpegAudioFilter; // optional audio filters or null

  const EffectDescriptor({
    required this.type,
    required this.name,
    this.ffmpegVideoFilter,
    this.ffmpegAudioFilter,
  });
}

class EffectsService {
  final MediaService _media = MediaService();

  // Descriptors for each effect. Filters are tuned for reasonable preview + processing.
  static final Map<EffectType, EffectDescriptor> descriptors = {
    EffectType.brightness: EffectDescriptor(
      type: EffectType.brightness,
      name: 'Brightness',
      ffmpegVideoFilter: () => 'eq=brightness=0.06',
    ),
    EffectType.contrast: EffectDescriptor(
      type: EffectType.contrast,
      name: 'Contrast',
      ffmpegVideoFilter: () => 'eq=contrast=1.3',
    ),
    EffectType.saturation: EffectDescriptor(
      type: EffectType.saturation,
      name: 'Saturation',
      ffmpegVideoFilter: () => 'eq=saturation=1.4',
    ),
    EffectType.sepia: EffectDescriptor(
      type: EffectType.sepia,
      name: 'Sepia',
      ffmpegVideoFilter: () => 'colorchannelmixer=.393:.769:.189:0:.349:.686:.168:0:.272:.534:.131',
    ),
    EffectType.grayscale: EffectDescriptor(
      type: EffectType.grayscale,
      name: 'Grayscale',
      ffmpegVideoFilter: () => 'hue=s=0',
    ),
    EffectType.slowMotion: EffectDescriptor(
      type: EffectType.slowMotion,
      name: 'Slow Motion',
      // video filter is setpts; audio via atempo (0.5) — for >2x slow you must chain atempo.
      ffmpegVideoFilter: () => 'setpts=2.0*PTS',
      ffmpegAudioFilter: () => 'atempo=0.5',
    ),
    EffectType.reverse: EffectDescriptor(
      type: EffectType.reverse,
      name: 'Reverse',
      ffmpegVideoFilter: () => 'reverse',
      ffmpegAudioFilter: () => 'areverse',
    ),
    EffectType.zoom: EffectDescriptor(
      type: EffectType.zoom,
      name: 'Zoom',
      // A zoom-in that slightly zooms in and centers. This expression animates zoom by time.
      ffmpegVideoFilter: () => "zoompan=z='1+0.2*sin(2*PI*t/5)':d=1:fps=25",
    ),
    EffectType.shake: EffectDescriptor(
      type: EffectType.shake,
      name: 'Shake',
      // Shake via small time-varying rotation; crop to original size (may add small black borders)
      ffmpegVideoFilter: () => "rotate=0.02*sin(12*t):ow=rotw(iw):oh=roth(ih),crop=iw:ih",
    ),
  };

  /// Generate a low-res JPEG thumbnail showing the effect applied to a frame (fast snapshot).
  /// Returns path to the generated file.
  Future<String> generateEffectThumbnail(String inputPath, EffectType effect,
      {int timeMs = 1000, int maxHeight = 160}) async {
    final desc = descriptors[effect]!;
    // Output path (jpg)
    final outPath = await _media.outputPathFor('effect_thumb_${desc.name}', 'jpg');

    // Build -vf part (scale plus effect)
    final vfParts = <String>[];
    if (desc.ffmpegVideoFilter != null) vfParts.add(desc.ffmpegVideoFilter!());
    vfParts.add('scale=-2:${maxHeight}'); // keep width even
    final vf = vfParts.join(',');

    // Use -ss before -i to seek quickly, then grab a single frame
    final ss = (timeMs / 1000.0).toStringAsFixed(3);
    final cmd = '-ss $ss -i "${inputPath}" -frames:v 1 -vf "$vf" -y "${outPath}"';

    final session = await FFmpegKit.execute(cmd);
    final rc = await session.getReturnCode();
    if (ReturnCode.isSuccess(rc)) {
      return outPath;
    } else {
      final logs = await session.getAllLogsAsString();
      throw Exception('FFmpeg preview thumbnail failed: rc=$rc logs=$logs');
    }
  }

  /// Apply an effect to a file and write a new file; returns path to processed file.
  /// This is synchronous from Dart's perspective (it blocks until FFmpeg finishes).
  Future<String> applyEffectToFile(String inputPath, EffectType effect,
      {String? outputExt}) async {
    final desc = descriptors[effect]!;
    final ext = outputExt ?? _getExtension(inputPath) ?? 'mp4';
    final outPath = await _media.outputPathFor('effect_${desc.name}', ext);

    // For simple color filters:
    if (effect == EffectType.brightness ||
        effect == EffectType.contrast ||
        effect == EffectType.saturation ||
        effect == EffectType.sepia ||
        effect == EffectType.grayscale) {
      final vf = desc.ffmpegVideoFilter!.call();
      final cmd = '-i "${inputPath}" -vf "$vf" -c:v libx264 -preset veryfast -crf 23 -c:a copy -y "${outPath}"';
      final session = await FFmpegKit.execute(cmd);
      final rc = await session.getReturnCode();
      if (ReturnCode.isSuccess(rc)) {
        return outPath;
      } else {
        final logs = await session.getAllLogsAsString();
        throw Exception('FFmpeg effect failed: rc=$rc logs=$logs');
      }
    }

    // Slow motion: adjust video pts and slow audio with atempo (0.5)
    if (effect == EffectType.slowMotion) {
      // For audio we use atempo=0.5; atempo supports between 0.5-2.0. If needed chain filters for other speeds.
      final vfilter = desc.ffmpegVideoFilter!.call();
      final afilter = desc.ffmpegAudioFilter!.call();
      final cmd =
          '-i "${inputPath}" -vf "$vfilter" -af "$afilter" -c:v libx264 -preset veryfast -crf 23 -c:a aac -b:a 128k -y "${outPath}"';
      final session = await FFmpegKit.execute(cmd);
      final rc = await session.getReturnCode();
      if (ReturnCode.isSuccess(rc)) {
        return outPath;
      } else {
        final logs = await session.getAllLogsAsString();
        throw Exception('FFmpeg slow motion failed: rc=$rc logs=$logs');
      }
    }

    // Reverse: reverse both video and audio (may be memory/disk heavy)
    if (effect == EffectType.reverse) {
      // Using intermediate because reverse requires stream-level buffering for audio+video;
      // we try direct filters (may fail on some formats).
      final cmd = '-i "${inputPath}" -vf "reverse" -af "areverse" -c:v libx264 -preset veryfast -crf 23 -c:a aac -b:a 128k -y "${outPath}"';
      final session = await FFmpegKit.execute(cmd);
      final rc = await session.getReturnCode();
      if (ReturnCode.isSuccess(rc)) {
        return outPath;
      } else {
        final logs = await session.getAllLogsAsString();
        throw Exception('FFmpeg reverse failed: rc=$rc logs=$logs');
      }
    }

    // Zoom (animated) and Shake effects: use provided video filters (may be expensive)
    if (effect == EffectType.zoom || effect == EffectType.shake) {
      final vf = desc.ffmpegVideoFilter!.call();
      final cmd = '-i "${inputPath}" -vf "$vf" -c:v libx264 -preset veryfast -crf 23 -c:a copy -y "${outPath}"';
      final session = await FFmpegKit.execute(cmd);
      final rc = await session.getReturnCode();
      if (ReturnCode.isSuccess(rc)) {
        return outPath;
      } else {
        final logs = await session.getAllLogsAsString();
        throw Exception('FFmpeg zoom/shake failed: rc=$rc logs=$logs');
      }
    }

    // Fallback: copy file
    final fallbackCmd = '-i "${inputPath}" -c copy -y "${outPath}"';
    final session = await FFmpegKit.execute(fallbackCmd);
    final rc = await session.getReturnCode();
    if (ReturnCode.isSuccess(rc)) {
      return outPath;
    } else {
      final logs = await session.getAllLogsAsString();
      throw Exception('FFmpeg fallback copy failed: rc=$rc logs=$logs');
    }
  }

  String? _getExtension(String path) {
    final ext = p.extension(path);
    if (ext.isEmpty) return null;
    return ext.replaceFirst('.', '').toLowerCase();
  }
}
