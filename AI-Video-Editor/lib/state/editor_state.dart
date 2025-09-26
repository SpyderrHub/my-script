import 'package:flutter/foundation.dart';

@immutable
class ClipModel {
  final String id;
  final String path; // absolute path to file
  final int startMs; // start point inside original file (ms)
  final int endMs; // end point inside original file (ms)
  final int durationMs; // duration of the selected range in ms
  final String? thumbnailPath; // cached thumbnail

  const ClipModel({
    required this.id,
    required this.path,
    required this.startMs,
    required this.endMs,
    required this.durationMs,
    this.thumbnailPath,
  });

  ClipModel copyWith({
    String? id,
    String? path,
    int? startMs,
    int? endMs,
    int? durationMs,
    String? thumbnailPath,
  }) {
    return ClipModel(
      id: id ?? this.id,
      path: path ?? this.path,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      durationMs: durationMs ?? this.durationMs,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'startMs': startMs,
        'endMs': endMs,
        'durationMs': durationMs,
        'thumbnailPath': thumbnailPath,
      };
}

@immutable
class EditorModel {
  final List<ClipModel> clips;
  final List<String> effects;

  const EditorModel({
    this.clips = const [],
    this.effects = const [],
  });

  EditorModel copyWith({
    List<ClipModel>? clips,
    List<String>? effects,
  }) {
    return EditorModel(
      clips: clips ?? this.clips,
      effects: effects ?? this.effects,
    );
  }

  Map<String, dynamic> toJson() => {
        'clips': clips.map((c) => c.toJson()).toList(),
        'effects': effects,
      };
}
