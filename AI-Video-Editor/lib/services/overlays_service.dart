// overlays_service.dart
// Apply overlays (stickers/GIFs/images/text) onto a clip using FFmpeg overlay/drawtext filters.
import 'dart:io';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'media_service.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../state/editor_state.dart';

class OverlaysService {
  final MediaService _media = MediaService();
  final _uuid = const Uuid();

  /// Apply a single overlay to a clip and write a new output file.
  /// Position and size use relative 0..1 coordinates and are translated to pixel values using video size.
  ///
  /// For GIFs we use `-ignore_loop 0` to let GIF animate throughout its duration.
  Future<String> applyOverlayToFile(String inputPath, OverlayModel overlay) async {
    final ext = _getExtension(inputPath) ?? 'mp4';
    final outPath = await _media.outputPathFor('overlay_${overlay.id}', ext);

    // Convert relative x,y,width,height to expressions using main w/h: x=main_w*X; y=main_h*Y; overlay_w=main_w*W
    // For drawtext we need a fontfile; overlay.sourcePath for text may encode the text in overlay.sourcePath or overlay.textStyle.text
    final xExpr = '(main_w*${overlay.x.toStringAsFixed(3)})';
    final yExpr = '(main_h*${overlay.y.toStringAsFixed(3)})';
    final wExpr = '(main_w*${overlay.width.toStringAsFixed(3)})';
    final hExpr = '(main_h*${overlay.height.toStringAsFixed(3)})';
    final enableExpr = "between(t,${(overlay.startMs / 1000.0).toStringAsFixed(3)},${(overlay.endMs / 1000.0).toStringAsFixed(3)})";

    String cmd;
    if (overlay.type == OverlayType.sticker || overlay.type == OverlayType.image) {
      // simple overlay input
      // -i main -i sticker -filter_complex "[1:v]scale=${wExpr}:${hExpr}[ov];[0:v][ov]overlay=${xExpr}:${yExpr}:enable='${enableExpr}'"
      cmd =
          '-i "${inputPath}" -i "${overlay.sourcePath}" -filter_complex "[1:v]scale=${wExpr}:${hExpr}[ov];[0:v][ov]overlay=${xExpr}:${yExpr}:enable=\'${enableExpr}\'" -c:v libx264 -preset veryfast -crf 23 -c:a copy -y "${outPath}"';
    } else if (overlay.type == OverlayType.gif) {
      // GIF may loop; use -ignore_loop 0 before -i gif to ensure animation; also we may need to use format=rgba
      cmd =
          '-i "${inputPath}" -ignore_loop 0 -i "${overlay.sourcePath}" -filter_complex "[1:v]scale=${wExpr}:${hExpr}[ov];[0:v][ov]overlay=${xExpr}:${yExpr}:enable=\'${enableExpr}\'" -c:v libx264 -preset veryfast -crf 23 -c:a copy -y "${outPath}"';
    } else if (overlay.type == OverlayType.text) {
      // use drawtext. fontFile should be a path to a ttf; if not provided, use system default (may vary).
      final ts = overlay.textStyle!;
      final fontfileArg = ts.fontFile != null ? "fontfile='${ts.fontFile}'" : '';
      final fontSizeExpr = (ts.fontSize).toStringAsFixed(0);
      final fontColor = ts.colorHex;
      // x & y expressions using main_w/h and overlay offset
      // drawtext supports x/y expressions directly
      // enable draws text only between start/end
      final drawtext =
          "drawtext=${fontfileArg}:text='${_escapeDrawText(ts.text)}':fontcolor=${fontColor}:fontsize=${fontSizeExpr}:x=${xExpr}:y=${yExpr}:enable='${enableExpr}'";
      cmd =
          '-i "${inputPath}" -vf "${drawtext}" -c:v libx264 -preset veryfast -crf 23 -c:a copy -y "${outPath}"';
    } else {
      // fallback: copy
      cmd = '-i "${inputPath}" -c copy -y "${outPath}"';
    }

    final session = await FFmpegKit.execute(cmd);
    final rc = await session.getReturnCode();
    if (ReturnCode.isSuccess(rc)) {
      return outPath;
    } else {
      final logs = await session.getAllLogsAsString();
      throw Exception('Apply overlay failed: rc=$rc logs=$logs');
    }
  }

  String _escapeDrawText(String t) {
    return t.replaceAll(':', '\\:').replaceAll("'", "\\'");
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
