import 'package:equatable/equatable.dart';
import '../../../core/models/models.dart';

abstract class EditorEvent extends Equatable {
  const EditorEvent();
  @override
  List<Object?> get props => [];
}

/// User added a sticker to the canvas.
class StickerAdded extends EditorEvent {
  final StickerItem sticker;
  const StickerAdded(this.sticker);
  @override
  List<Object?> get props => [sticker];
}

/// User dragged/scaled/rotated a sticker.
class StickerUpdated extends EditorEvent {
  final StickerItem sticker;
  const StickerUpdated(this.sticker);
  @override
  List<Object?> get props => [sticker];
}

/// User deleted a sticker.
class StickerDeleted extends EditorEvent {
  final String stickerId;
  const StickerDeleted(this.stickerId);
  @override
  List<Object?> get props => [stickerId];
}

/// User added a text overlay.
class TextAdded extends EditorEvent {
  final TextItem textItem;
  const TextAdded(this.textItem);
  @override
  List<Object?> get props => [textItem];
}

/// User edited an existing text overlay.
class TextUpdated extends EditorEvent {
  final TextItem textItem;
  const TextUpdated(this.textItem);
  @override
  List<Object?> get props => [textItem];
}

/// User deleted a text overlay.
class TextDeleted extends EditorEvent {
  final String textId;
  const TextDeleted(this.textId);
  @override
  List<Object?> get props => [textId];
}

/// User selected a border.
class BorderSelected extends EditorEvent {
  final String? borderAssetPath; // null = no border
  const BorderSelected(this.borderAssetPath);
  @override
  List<Object?> get props => [borderAssetPath];
}

/// User tapped "Done" — compose the final image.
class EditorConfirmed extends EditorEvent {
  const EditorConfirmed();
}
