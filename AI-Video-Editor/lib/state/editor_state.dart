// Updated editor_state.dart - adds TransitionModel and OverlayModel
import 'package:flutter/foundation.dart';

@immutable
class ClipModel {
  final String id;
  final String path; // absolute path to file
  final int startMs; // start point inside original file (ms)
  final int endMs; // end point inside original file (ms)
  final int durationMs; // duration of the selected range in ms
  final String? thumbnailPath; // cached thumbnail
  final List<OverlayModel> overlays; // overlays applied on this clip

  const ClipModel({
    required this.id,
    required this.path,
    required this.startMs,
    required this.endMs,
    required this.durationMs,
    this.thumbnailPath,
    this.overlays = const [],
  });

  ClipModel copyWith({
    String? id,
    String? path,
    int? startMs,
    int? endMs,
    int? durationMs,
    String? thumbnailPath,
    List<OverlayModel>? overlays,
  }) {
    return ClipModel(
      id: id ?? this.id,
      path: path ?? this.path,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      durationMs: durationMs ?? this.durationMs,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      overlays: overlays ?? this.overlays,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'startMs': startMs,
        'endMs': endMs,
        'durationMs': durationMs,
        'thumbnailPath': thumbnailPath,
        'overlays': overlays.map((o) => o.toJson()).toList(),
      };
}

@immutable
class OverlayModel {
  final String id;
  final OverlayType type; // sticker, gif, image, text
  final String sourcePath; // path to sticker/gif/image or font/text content reference for text
  final double x; // relative 0..1 (left)
  final double y; // relative 0..1 (top)
  final double width; // relative 0..1
  final double height; // relative 0..1
  final int startMs; // when overlay appears (relative to clip) (ms)
  final int endMs; // when overlay disappears (relative to clip) (ms)
  final TextStyleModel? textStyle; // for text overlays

  const OverlayModel({
    required this.id,
    required this.type,
    required this.sourcePath,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.startMs,
    required this.endMs,
    this.textStyle,
  });

  OverlayModel copyWith({
    String? id,
    OverlayType? type,
    String? sourcePath,
    double? x,
    double? y,
    double? width,
    double? height,
    int? startMs,
    int? endMs,
    TextStyleModel? textStyle,
  }) {
    return OverlayModel(
      id: id ?? this.id,
      type: type ?? this.type,
      sourcePath: sourcePath ?? this.sourcePath,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      textStyle: textStyle ?? this.textStyle,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.toString(),
        'sourcePath': sourcePath,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'startMs': startMs,
        'endMs': endMs,
        'textStyle': textStyle?.toJson(),
      };
}

enum OverlayType { sticker, gif, image, text }

@immutable
class TextStyleModel {
  final String text; // actual text content
  final String? fontFile; // optional font path
  final double fontSize;
  final String colorHex; // '#RRGGBB' or similar
  final bool bold;
  final bool italic;
  final double rotate; // degrees
  final String? animation; // e.g., 'fade', 'slide', 'bounce'

  const TextStyleModel({
    required this.text,
    this.fontFile,
    this.fontSize = 24.0,
    this.colorHex = '#FFFFFFFF',
    this.bold = false,
    this.italic = false,
    this.rotate = 0.0,
    this.animation,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'fontFile': fontFile,
        'fontSize': fontSize,
        'colorHex': colorHex,
        'bold': bold,
        'italic': italic,
        'rotate': rotate,
        'animation': animation,
      };
}

@immutable
class TransitionModel {
  final String id;
  final TransitionType type;
  final int durationMs; // duration of transition in ms
  final String fromClipId;
  final String toClipId;
  // Additional parameters (direction, intensity)
  final Map<String, dynamic>? params;

  const TransitionModel({
    required this.id,
    required this.type,
    required this.durationMs,
    required this.fromClipId,
    required this.toClipId,
    this.params,
  });

  TransitionModel copyWith({
    String? id,
    TransitionType? type,
    int? durationMs,
    String? fromClipId,
    String? toClipId,
    Map<String, dynamic>? params,
  }) {
    return TransitionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      durationMs: durationMs ?? this.durationMs,
      fromClipId: fromClipId ?? this.fromClipId,
      toClipId: toClipId ?? this.toClipId,
      params: params ?? this.params,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.toString(),
        'durationMs': durationMs,
        'fromClipId': fromClipId,
        'toClipId': toClipId,
        'params': params,
      };
}

enum TransitionType { fade, slide, zoom, glitch, flip3d }

@immutable
class EditorModel {
  final List<ClipModel> clips;
  final List<String> effects;
  final List<TransitionModel> transitions; // transitions between clips

  const EditorModel({
    this.clips = const [],
    this.effects = const [],
    this.transitions = const [],
  });

  EditorModel copyWith({
    List<ClipModel>? clips,
    List<String>? effects,
    List<TransitionModel>? transitions,
  }) {
    return EditorModel(
      clips: clips ?? this.clips,
      effects: effects ?? this.effects,
      transitions: transitions ?? this.transitions,
    );
  }

  Map<String, dynamic> toJson() => {
        'clips': clips.map((c) => c.toJson()).toList(),
        'effects': effects,
        'transitions': transitions.map((t) => t.toJson()).toList(),
      };
}
