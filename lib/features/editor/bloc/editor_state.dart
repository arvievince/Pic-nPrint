import 'package:equatable/equatable.dart';
import '../../../core/models/models.dart';

/// Single state class (data class pattern) — the editor state is a snapshot
/// of all overlays plus the composition status.
class EditorState extends Equatable {
  final List<StickerItem> stickers;
  final List<TextItem>    texts;
  final String?           borderAssetPath;
  final bool              isComposing;   // true while CompositionService runs
  final String?           composedPath;  // set when composition is done
  final String?           error;

  const EditorState({
    this.stickers        = const [],
    this.texts           = const [],
    this.borderAssetPath,
    this.isComposing     = false,
    this.composedPath,
    this.error,
  });

  EditorState copyWith({
    List<StickerItem>? stickers,
    List<TextItem>?    texts,
    String?            borderAssetPath,
    bool?              isComposing,
    String?            composedPath,
    String?            error,
  }) {
    return EditorState(
      stickers:        stickers        ?? this.stickers,
      texts:           texts           ?? this.texts,
      borderAssetPath: borderAssetPath ?? this.borderAssetPath,
      isComposing:     isComposing     ?? this.isComposing,
      composedPath:    composedPath    ?? this.composedPath,
      error:           error           ?? this.error,
    );
  }

  @override
  List<Object?> get props =>
      [stickers, texts, borderAssetPath, isComposing, composedPath, error];
}
