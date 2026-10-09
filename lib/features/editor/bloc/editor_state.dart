import 'package:equatable/equatable.dart';
import '../../../core/models/models.dart';

const Object _sentinel = Object();

/// Single state class (data class pattern) — the editor state is a snapshot
/// of all overlays plus the composition status.
class EditorState extends Equatable {
  final List<StickerItem> stickers;
  final List<TextItem> texts;
  final String? borderAssetPath;
  final bool isComposing; // true while CompositionService runs
  final String? composedPath; // set when composition is done
  final String? error;

  const EditorState({
    this.stickers = const [],
    this.texts = const [],
    this.borderAssetPath,
    this.isComposing = false,
    this.composedPath,
    this.error,
  });

  EditorState copyWith({
    List<StickerItem>? stickers,
    List<TextItem>? texts,
    Object? borderAssetPath = _sentinel,
    bool? isComposing,
    Object? composedPath = _sentinel,
    Object? error = _sentinel,
  }) {
    return EditorState(
      stickers: stickers ?? this.stickers,
      texts: texts ?? this.texts,
      borderAssetPath: borderAssetPath == _sentinel
          ? this.borderAssetPath
          : borderAssetPath as String?,
      isComposing: isComposing ?? this.isComposing,
      composedPath: composedPath == _sentinel
          ? this.composedPath
          : composedPath as String?,
      error: error == _sentinel ? this.error : error as String?,
    );
  }

  @override
  List<Object?> get props =>
      [stickers, texts, borderAssetPath, isComposing, composedPath, error];
}
