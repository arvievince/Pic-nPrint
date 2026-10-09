import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/models.dart';
import '../../../core/services/composition_service.dart';
import 'editor_event.dart';
import 'editor_state.dart';

/// Manages the editor canvas: stickers, text overlays, and borders.
/// Triggers [CompositionService] when the user confirms.
///
/// Flow:
///   EditorScreen shows canvas with RepaintBoundary.
///   User adds/moves stickers → StickerAdded/StickerUpdated → state updates.
///   User taps "Done" → EditorConfirmed
///     → isComposing = true (show loading)
///     → CompositionService.compose() runs in isolate
///     → composedPath set → screen navigates to /output
///
class EditorBloc extends Bloc<EditorEvent, EditorState> {
  final CompositionService _compositionService;
  final SessionModel session;

  EditorBloc({
    required CompositionService compositionService,
    required this.session,
  })  : _compositionService = compositionService,
        super(const EditorState()) {
    on<StickerAdded>(_onStickerAdded);
    on<StickerUpdated>(_onStickerUpdated);
    on<StickerDeleted>(_onStickerDeleted);
    on<TextAdded>(_onTextAdded);
    on<TextUpdated>(_onTextUpdated);
    on<TextDeleted>(_onTextDeleted);
    on<BorderSelected>(_onBorderSelected);
    on<EditorConfirmed>(_onConfirmed);
  }

  // ─── Sticker Handlers ────────────────────────────────────────────────────────

  void _onStickerAdded(StickerAdded event, Emitter<EditorState> emit) {
    emit(state.copyWith(stickers: [...state.stickers, event.sticker]));
  }

  void _onStickerUpdated(StickerUpdated event, Emitter<EditorState> emit) {
    final updated = state.stickers
        .map((s) => s.id == event.sticker.id ? event.sticker : s)
        .toList();
    emit(state.copyWith(stickers: updated));
  }

  void _onStickerDeleted(StickerDeleted event, Emitter<EditorState> emit) {
    emit(state.copyWith(
      stickers: state.stickers.where((s) => s.id != event.stickerId).toList(),
    ));
  }

  // ─── Text Handlers ────────────────────────────────────────────────────────────

  void _onTextAdded(TextAdded event, Emitter<EditorState> emit) {
    emit(state.copyWith(texts: [...state.texts, event.textItem]));
  }

  void _onTextUpdated(TextUpdated event, Emitter<EditorState> emit) {
    final updated = state.texts
        .map((t) => t.id == event.textItem.id ? event.textItem : t)
        .toList();
    emit(state.copyWith(texts: updated));
  }

  void _onTextDeleted(TextDeleted event, Emitter<EditorState> emit) {
    emit(state.copyWith(
      texts: state.texts.where((t) => t.id != event.textId).toList(),
    ));
  }

  // ─── Border ───────────────────────────────────────────────────────────────────

  void _onBorderSelected(BorderSelected event, Emitter<EditorState> emit) {
    emit(state.copyWith(borderAssetPath: event.borderAssetPath));
  }

  // ─── Compose ──────────────────────────────────────────────────────────────────

  Future<void> _onConfirmed(
      EditorConfirmed event, Emitter<EditorState> emit) async {
    emit(state.copyWith(isComposing: true));

    try {
      final composedPath = await _compositionService.compose(
        session: session,
        stickers: state.stickers,
        texts: state.texts,
        borderAssetPath: state.borderAssetPath,
      );
      emit(state.copyWith(isComposing: false, composedPath: composedPath));
    } catch (e) {
      emit(state.copyWith(
        isComposing: false,
        error: 'Failed to compose image: $e',
      ));
    }
  }
}
