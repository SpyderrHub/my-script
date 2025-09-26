import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'editor_state.dart';
import 'package:uuid/uuid.dart';
import '../services/media_service.dart';
import '../services/ffmpeg_service.dart';

final mediaServiceProvider = Provider<MediaService>((ref) => MediaService());
final ffmpegServiceProvider = Provider<FfmpegService>((ref) => FfmpegService());

final editorProvider = StateNotifierProvider<EditorNotifier, EditorModel>((ref) {
  return EditorNotifier(ref.read);
});

class EditorNotifier extends StateNotifier<EditorModel> {
  final Reader read;
  final _uuid = const Uuid();

  EditorNotifier(this.read) : super(const EditorModel());

  Future<void> importFiles() async {
    final mediaService = read(mediaServiceProvider);
    final picked = await mediaService.pickMedia();
    if (picked == null || picked.isEmpty) return;

    // convert picked items into ClipModel entries; do thumb generation and duration lookups
    final List<ClipModel> newClips = [];
    for (final p in picked) {
      final durationMs = await mediaService.getMediaDurationMs(p);
      final thumb = await mediaService.getThumbnail(p, timeMs: 0);
      final clip = ClipModel(
        id: _uuid.v4(),
        path: p,
        startMs: 0,
        endMs: durationMs,
        durationMs: durationMs,
        thumbnailPath: thumb,
      );
      newClips.add(clip);
    }

    state = state.copyWith(clips: [...state.clips, ...newClips]);
  }

  void removeClipById(String id) {
    state = state.copyWith(clips: state.clips.where((c) => c.id != id).toList());
  }

  Future<void> reorderClips(int oldIndex, int newIndex) async {
    final list = List<ClipModel>.from(state.clips);
    if (oldIndex < newIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = state.copyWith(clips: list);
  }

  // Trim: replace the clip with a trimmed version (runs ffmpeg and updates path, duration, thumbnail)
  Future<void> trimClip(String id, int newStartMs, int newEndMs) async {
    final ffmpeg = read(ffmpegServiceProvider);
    final media = read(mediaServiceProvider);

    final idx = state.clips.indexWhere((c) => c.id == id);
    if (idx < 0) return;
    final clip = state.clips[idx];

    final outPath = await ffmpeg.trimClip(clip.path, newStartMs, newEndMs);
    final outDuration = newEndMs - newStartMs;
    final thumb = await media.getThumbnail(outPath, timeMs: 0);

    final newClip = clip.copyWith(
      path: outPath,
      startMs: 0,
      endMs: outDuration,
      durationMs: outDuration,
      thumbnailPath: thumb,
      id: _uuid.v4(),
    );

    final newList = List<ClipModel>.from(state.clips)..removeAt(idx)..insert(idx, newClip);
    state = state.copyWith(clips: newList);
  }

  // Split clip at a timestamp (relative to clip start). Replaces original with two new clips created by ffmpeg.
  Future<void> splitClip(String id, int splitMs) async {
    final ffmpeg = read(ffmpegServiceProvider);
    final media = read(mediaServiceProvider);

    final idx = state.clips.indexWhere((c) => c.id == id);
    if (idx < 0) return;
    final clip = state.clips[idx];

    if (splitMs <= 0 || splitMs >= clip.durationMs) return;

    final results = await ffmpeg.splitClip(clip.path, splitMs, clip.durationMs);
    // results: [pathA, pathB]
    final aDur = splitMs;
    final bDur = clip.durationMs - splitMs;

    final thumbA = await media.getThumbnail(results[0], timeMs: 0);
    final thumbB = await media.getThumbnail(results[1], timeMs: 0);

    final aClip = ClipModel(
      id: _uuid.v4(),
      path: results[0],
      startMs: 0,
      endMs: aDur,
      durationMs: aDur,
      thumbnailPath: thumbA,
    );
    final bClip = ClipModel(
      id: _uuid.v4(),
      path: results[1],
      startMs: 0,
      endMs: bDur,
      durationMs: bDur,
      thumbnailPath: thumbB,
    );

    final newList = List<ClipModel>.from(state.clips)
      ..removeAt(idx)
      ..insertAll(idx, [aClip, bClip]);
    state = state.copyWith(clips: newList);
  }
}
