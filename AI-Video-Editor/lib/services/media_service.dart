import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart';

/// MediaService: pick local files, create thumbnails, get duration.
/// Thumbnails are generated at low resolution for performance.
class MediaService {
  // Pick multiple video or image files
  Future<List<String>?> pickMedia() async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.media);
    if (res == null || res.paths.isEmpty) return null;
    return res.paths.whereType<String>().toList();
  }

  // Generate thumbnail at given position (ms). Returns a file path.
  Future<String?> getThumbnail(String filePath, {int timeMs = 0, int maxHeight = 128}) async {
    try {
      final thumb = await VideoThumbnail.thumbnailFile(
        video: filePath,
        imageFormat: ImageFormat.JPEG,
        maxHeight: maxHeight,
        timeMs: timeMs,
        quality: 70,
      );
      return thumb;
    } catch (e) {
      // For non-video (images) return the image path
      if (filePath.toLowerCase().endsWith('.jpg') ||
          filePath.toLowerCase().endsWith('.jpeg') ||
          filePath.toLowerCase().endsWith('.png')) {
        return filePath;
      }
      return null;
    }
  }

  // Get duration in ms using a short VideoPlayerController lifecycle.
  Future<int> getMediaDurationMs(String filePath) async {
    try {
      final controller = VideoPlayerController.file(File(filePath));
      await controller.initialize();
      final dur = controller.value.duration.inMilliseconds;
      await controller.dispose();
      return dur;
    } catch (e) {
      // If failing (image or unknown), return 0
      return 0;
    }
  }

  // Provide an app-local output path for ffmpeg to write outputs
  Future<String> outputPathFor(String prefix, String ext) async {
    final dir = await getApplicationDocumentsDirectory();
    final filename = '$prefix-${DateTime.now().millisecondsSinceEpoch}.$ext';
    return '${dir.path}/$filename';
  }
}
