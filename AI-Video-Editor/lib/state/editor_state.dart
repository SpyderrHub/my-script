import 'package:flutter/foundation.dart';

// Simple immutable editor model
@immutable
class EditorModel {
  final List<String> clips;
  final List<String> effects;
  final List<List<String>> _history; // for simple undo/redo
  final int _historyIndex;

  const EditorModel({
    this.clips = const [],
    this.effects = const [],
    List<List<String>>? history,
    int historyIndex = 0,
  })  : _history = history ?? const [],
        _historyIndex = historyIndex;

  EditorModel copyWith({
    List<String>? clips,
    List<String>? effects,
    List<List<String>>? history,
    int? historyIndex,
  }) {
    return EditorModel(
      clips: clips ?? this.clips,
      effects: effects ?? this.effects,
      history: history ?? this._history,
      historyIndex: historyIndex ?? _historyIndex,
    );
  }

  // A helpful representation for sending to backend
  Map<String, dynamic> toJson() => {
        'clips': clips,
        'effects': effects,
      };
}
