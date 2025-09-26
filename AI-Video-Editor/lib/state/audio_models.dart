// audio_models.dart
import 'package:flutter/foundation.dart';

@immutable
class AudioTrackModel {
  final String id;
  final String path; // absolute path to audio file
  final int startMs; // start point inside original audio (ms)
  final int endMs; // end point inside original audio (ms)
  final int durationMs; // duration of the selected range in ms (endMs - startMs)
  final int timelineOffsetMs; // where this track starts on the project timeline (ms)
  final double volume; // 0.0 - 2.0 (1.0 = original)
  final int fadeInMs; // fade-in duration (ms)
  final int fadeOutMs; // fade-out duration (ms)
  final bool muted;
  final bool isVoiceover;

  const AudioTrackModel({
    required this.id,
    required this.path,
    required this.startMs,
    required this.endMs,
    required this.durationMs,
    this.timelineOffsetMs = 0,
    this.volume = 1.0,
    this.fadeInMs = 0,
    this.fadeOutMs = 0,
    this.muted = false,
    this.isVoiceover = false,
  });

  AudioTrackModel copyWith({
    String? id,
    String? path,
    int? startMs,
    int? endMs,
    int? durationMs,
    int? timelineOffsetMs,
    double? volume,
    int? fadeInMs,
    int? fadeOutMs,
    bool? muted,
    bool? isVoiceover,
  }) {
    return AudioTrackModel(
      id: id ?? this.id,
      path: path ?? this.path,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      durationMs: durationMs ?? this.durationMs,
      timelineOffsetMs: timelineOffsetMs ?? this.timelineOffsetMs,
      volume: volume ?? this.volume,
      fadeInMs: fadeInMs ?? this.fadeInMs,
      fadeOutMs: fadeOutMs ?? this.fadeOutMs,
      muted: muted ?? this.muted,
      isVoiceover: isVoiceover ?? this.isVoiceover,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'startMs': startMs,
        'endMs': endMs,
        'durationMs': durationMs,
        'timelineOffsetMs': timelineOffsetMs,
        'volume': volume,
        'fadeInMs': fadeInMs,
        'fadeOutMs': fadeOutMs,
        'muted': muted,
        'isVoiceover': isVoiceover,
      };
}
