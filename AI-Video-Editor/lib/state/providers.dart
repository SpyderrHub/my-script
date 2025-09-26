// providers.dart (extended: transitions & overlays)
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'editor_state.dart';
import 'package:uuid/uuid.dart';
import '../services/media_service.dart';
import '../services/ffmpeg_service.dart';
import '../services/effects_service.dart';
import '../services/transitions_service.dart';
import '../services/overlays_service.dart';

final mediaServiceProvider = Provider<MediaService>((ref) => MediaService());
final ffmpegServiceProvider = Provider<FfmpegService>((ref) => FfmpegService());
final effectsServiceProvider = Provider<EffectsService>((ref) => EffectsService());
final transitionsServiceProvider = Provider<TransitionsService>((ref) => TransitionsService());
final overlaysServiceProvider = Provider<OverlaysService>((ref) => OverlaysService());

final editorProvider = StateNotifierProvider<EditorNotifier, EditorModel>((ref) {
  return EditorNotifier(ref.read);
});

class EditorNotifier extends StateNotifier<EditorModel> {
  final Reader read;
  final _uuid = const Uuid();

  EditorNotifier(this.read) : super(const EditorModel());

  // ... existing methods omitted for brevity (import/files/trim/split/reorder/applyEffectToClip)
  // (Assume previous implementations are unchanged and still present.)

  /// Add a transition between clip at index and index+1 with given type/duration.
  /// This will produce a new merged clip replacing the two clips in the timeline.
  Future<void> addTransitionAtIndex(int index, TransitionType type, int durationMs) async {
    if (index < 0 || index >= state.clips.length - 1) return;
    final transitionsSvc = read(transitionsServiceProvider);
    final a = state.clips[index];
    final b = state.clips[index + 1];

    final transition = TransitionModel(
      id: _uuid.v4(),
      type: type,
      durationMs: durationMs,
      fromClipId: a.id,
      toClipId: b.id,
    );

    // Apply transition (this creates a new merged file)
    final outPath = await transitionsSvc.applyTransition(a.path, b.path, transition);

    // create a new ClipModel with merged content
    final media = read(mediaServiceProvider);
    final outDur = await media.getMediaDurationMs(outPath);
    final thumb = await media.getThumbnail(outPath, timeMs: 0);

    final mergedClip = ClipModel(
      id: _uuid.v4(),
      path: outPath,
      startMs: 0,
      endMs: outDur,
      durationMs: outDur,
      thumbnailPath: thumb,
      overlays: [],
    );

    // Replace a and b with mergedClip and remove any transitions touching them
    final newClips = List<ClipModel>.from(state.clips)
      ..removeAt(index)
      ..removeAt(index)
      ..insert(index, mergedClip);

    // Remove transitions that reference removed clips
    final newTransitions = state.transitions.where((t) => t.fromClipId != a.id && t.toClipId != b.id).toList();

    state = state.copyWith(clips: newClips, transitions: newTransitions);
  }

  /// Add an overlay to a clip: we both record the overlay model in the ClipModel and optionally process the clip to bake the overlay.
  /// For interactive edits we store OverlayModel and only process/bake at export time; here we provide a convenience to bake immediately (applyOverlayAndBake).
  Future<void> addOverlayToClip(String clipId, OverlayModel overlay, {bool bakeNow = false}) async {
    final idx = state.clips.indexWhere((c) => c.id == clipId);
    if (idx < 0) return;
    final clip = state.clips[idx];

    // Add overlay metadata
    final newOverlays = List<OverlayModel>.from(clip.overlays)..add(overlay);
    var updatedClip = clip.copyWith(overlays: newOverlays);

    // If bakeNow, run overlays service to produce a new file with the overlay burned in
    if (bakeNow) {
      final overlaysSvc = read(overlaysServiceProvider);
      final outPath = await overlaysSvc.applyOverlayToFile(clip.path, overlay);
      final media = read(mediaServiceProvider);
      final outDur = await media.getMediaDurationMs(outPath);
      final thumb = await media.getThumbnail(outPath, timeMs: 0);

      updatedClip = updatedClip.copyWith(
        id: _uuid.v4(),
        path: outPath,
        startMs: 0,
        endMs: outDur,
        durationMs: outDur,
        thumbnailPath: thumb,
        overlays: [], // baked in => no more separate overlays
      );
    }

    final newList = List<ClipModel>.from(state.clips)..removeAt(idx)..insert(idx, updatedClip);
    state = state.copyWith(clips: newList);
  }
}
