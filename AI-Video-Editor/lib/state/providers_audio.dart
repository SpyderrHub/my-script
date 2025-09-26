// providers_audio.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../services/audio_service.dart';
import '../services/recording_service.dart';
import 'audio_models.dart';
import 'providers.dart' as main_providers; // to access editor provider if needed

final audioServiceProvider = Provider<AudioService>((ref) => AudioService());
final recordingServiceProvider = Provider<RecordingService>((ref) => RecordingService());

final audioTracksProvider = StateNotifierProvider<AudioTracksNotifier, List<AudioTrackModel>>((ref) {
  return AudioTracksNotifier(ref.read);
});

class AudioTracksNotifier extends StateNotifier<List<AudioTrackModel>> {
  final Reader read;
  final _uuid = const Uuid();

  AudioTracksNotifier(this.read) : super([]);

  Future<void> importAudioFiles() async {
    final audioSvc = read(audioServiceProvider);
    final picked = await audioSvc.pickAudioFiles();
    if (picked == null || picked.isEmpty) return;

    final List<AudioTrackModel> newTracks = [];
    for (final p in picked) {
      final dur = await audioSvc.getAudioDurationMs(p);
      final track = AudioTrackModel(
        id: _uuid.v4(),
        path: p,
        startMs: 0,
        endMs: dur,
        durationMs: dur,
        timelineOffsetMs: 0,
        volume: 1.0,
      );
      newTracks.add(track);
    }

    state = [...state, ...newTracks];
  }

  void removeTrack(String id) {
    state = state.where((t) => t.id != id).toList();
  }

  Future<void> cutTrack(String id, int newStartMs, int newEndMs) async {
    final audioSvc = read(audioServiceProvider);
    final idx = state.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final t = state[idx];
    final outPath = await audioSvc.trimAudio(t.path, newStartMs, newEndMs);
    final outDur = await audioSvc.getAudioDurationMs(outPath);
    final updated = t.copyWith(
      path: outPath,
      startMs: 0,
      endMs: outDur,
      durationMs: outDur,
    );
    final list = List<AudioTrackModel>.from(state)..removeAt(idx)..insert(idx, updated);
    state = list;
  }

  Future<void> setVolume(String id, double volume) async {
    final audioSvc = read(audioServiceProvider);
    final idx = state.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final t = state[idx];
    // apply change non-destructively: create an adjusted audio file (optional)
    final outPath = await audioSvc.applyVolumeAndFades(t.path, volume: volume, fadeInMs: t.fadeInMs, fadeOutMs: t.fadeOutMs);
    final outDur = await audioSvc.getAudioDurationMs(outPath);
    final updated = t.copyWith(path: outPath, volume: volume, durationMs: outDur);
    final list = List<AudioTrackModel>.from(state)..removeAt(idx)..insert(idx, updated);
    state = list;
  }

  Future<void> setFades(String id, {int? fadeInMs, int? fadeOutMs}) async {
    final audioSvc = read(audioServiceProvider);
    final idx = state.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final t = state[idx];
    final inMs = fadeInMs ?? t.fadeInMs;
    final outMs = fadeOutMs ?? t.fadeOutMs;
    final outPath = await audioSvc.applyVolumeAndFades(t.path, volume: t.volume, fadeInMs: inMs, fadeOutMs: outMs);
    final outDur = await audioSvc.getAudioDurationMs(outPath);
    final updated = t.copyWith(path: outPath, fadeInMs: inMs, fadeOutMs: outMs, durationMs: outDur);
    final list = List<AudioTrackModel>.from(state)..removeAt(idx)..insert(idx, updated);
    state = list;
  }

  void setTimelineOffset(String id, int offsetMs) {
    final idx = state.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final t = state[idx];
    final updated = t.copyWith(timelineOffsetMs: offsetMs);
    final list = List<AudioTrackModel>.from(state)..removeAt(idx)..insert(idx, updated);
    state = list;
  }

  Future<void> addVoiceoverFromRecording(String filePath, {int timelineOffsetMs = 0}) async {
    final audioSvc = read(audioServiceProvider);
    final dur = await audioSvc.getAudioDurationMs(filePath);
    final track = AudioTrackModel(
      id: _uuid.v4(),
      path: filePath,
      startMs: 0,
      endMs: dur,
      durationMs: dur,
      timelineOffsetMs: timelineOffsetMs,
      volume: 1.0,
      isVoiceover: true,
    );
    state = [...state, track];
  }
}
