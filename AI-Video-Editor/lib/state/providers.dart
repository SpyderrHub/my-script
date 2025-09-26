import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'editor_state.dart';

final editorProvider = StateNotifierProvider<EditorNotifier, EditorModel>((ref) {
  return EditorNotifier();
});

class EditorNotifier extends StateNotifier<EditorModel> {
  EditorNotifier() : super(const EditorModel());

  void addClip(String clipPath) {
    final updatedClips = List<String>.from(state.clips)..add(clipPath);
    _pushHistory(updatedClips);
    state = state.copyWith(clips: updatedClips);
  }

  void removeClip(String clipPath) {
    final updatedClips = List<String>.from(state.clips)..removeWhere((c) => c == clipPath);
    _pushHistory(updatedClips);
    state = state.copyWith(clips: updatedClips);
  }

  void addEffect(String effect) {
    if (state.effects.contains(effect)) return;
    final updated = List<String>.from(state.effects)..add(effect);
    state = state.copyWith(effects: updated);
  }

  void removeEffect(String effect) {
    final updated = List<String>.from(state.effects)..removeWhere((e) => e == effect);
    state = state.copyWith(effects: updated);
  }

  // Very simple undo/redo using a clip history (effects not included here for brevity)
  void _pushHistory(List<String> clips) {
    final history = List<List<String>>.from(state._history);
    history.add(clips);
    final idx = history.length - 1;
    state = state.copyWith(history: history, historyIndex: idx);
  }

  void undo() {
    final idx = state._historyIndex - 1;
    if (idx < 0 || state._history.isEmpty) return;
    final prevClips = state._history[idx];
    state = state.copyWith(clips: prevClips, historyIndex: idx);
  }

  void redo() {
    final idx = state._historyIndex + 1;
    if (idx >= state._history.length) return;
    final nextClips = state._history[idx];
    state = state.copyWith(clips: nextClips, historyIndex: idx);
  }
}
