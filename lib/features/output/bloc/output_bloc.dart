import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/models.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/supabase_storage_service.dart';
import '../../../core/services/printer_service.dart';
import 'output_event.dart';
import 'output_state.dart';

/// Orchestrates the save → upload → print pipeline.
///
/// Design constraints:
///   1. Local save happens first to ensure files exist on disk.
///   2. Printing and Supabase Cloud Upload run IN PARALLEL — printing
///      never blocks or waits for upload to finish.
///   3. If upload fails or local-only mode is active, printing still completes.
///   4. When both complete, OutputComplete is emitted with photoUrl and gifUrl.
class OutputBloc extends Bloc<OutputEvent, OutputState> {
  final StorageService _storageService;
  final SupabaseStorageService _supabaseService;
  final PrinterService _printerService;
  final AppDatabase _db;
  final SessionModel session;

  OutputBloc({
    required StorageService storageService,
    required SupabaseStorageService supabaseService,
    required PrinterService printerService,
    required AppDatabase db,
    required this.session,
  })  : _storageService = storageService,
        _supabaseService = supabaseService,
        _printerService = printerService,
        _db = db,
        super(const OutputSaving()) {
    on<OutputStarted>(_onStarted);
    on<UploadRetried>(_onUploadRetried);
    on<PrintRequested>(_onPrintRequested);
    on<QrDismissed>(_onQrDismissed);

    // Auto-start the pipeline when the bloc is created
    add(const OutputStarted());
  }

  // ─── Pipeline ─────────────────────────────────────────────────────────────

  Future<void> _onStarted(
      OutputStarted event, Emitter<OutputState> emit) async {
    // Step 1: Save locally
    emit(const OutputSaving());
    String? localPath;
    try {
      localPath = await _storageService.saveLocalFiles(session);
    } catch (_) {
      // Even if local save fails, continue with whatever path we have
      localPath = session.composedImagePath;
    }

    final sessionWithImage = session.copyWith(
      composedImagePath: localPath ?? session.composedImagePath,
    );

    // Step 2: Parallel Print + Cloud Upload
    emit(const OutputPrinting());

    final uploadFuture = _doUpload(sessionWithImage);
    final printFuture = _doPrint(emit, sessionWithImage.composedImagePath);

    final results = await Future.wait([
      uploadFuture,
      printFuture,
    ], eagerError: false);

    final uploadResult = results[0] as SupabaseUploadResult?;

    emit(OutputComplete(
      photoUrl: uploadResult?.photoUrl,
      gifUrl: uploadResult?.gifUrl,
    ));
  }

  Future<void> _onUploadRetried(
      UploadRetried event, Emitter<OutputState> emit) async {
    emit(const OutputUploading());
    try {
      final uploadResult = await _doUpload(session);
      emit(OutputComplete(
        photoUrl: uploadResult?.photoUrl,
        gifUrl: uploadResult?.gifUrl,
      ));
    } catch (e) {
      emit(OutputUploadFailed(e.toString()));
    }
  }

  Future<void> _onPrintRequested(
      PrintRequested event, Emitter<OutputState> emit) async {
    await _doPrint(emit, session.composedImagePath);
  }

  void _onQrDismissed(QrDismissed event, Emitter<OutputState> emit) {
    // Screen handles navigation back to attract — nothing to do in bloc.
  }

  // ─── Upload Helper ────────────────────────────────────────────────────────

  Future<SupabaseUploadResult?> _doUpload(SessionModel currentSession) async {
    try {
      final isLocalOnly =
          (await _db.getSetting('supabase_local_only')) == 'true';
      if (isLocalOnly) return null;

      return await _supabaseService.uploadSession(currentSession);
    } catch (e) {
      // Non-fatal: softcopy upload failure must not crash or prevent completion
      return null;
    }
  }

  // ─── Print Helper ─────────────────────────────────────────────────────────

  Future<void> _doPrint(
      Emitter<OutputState> emit, String? imagePath) async {
    if (imagePath == null) return;

    try {
      final printers = await _db.getAllPrinters();
      final defaultPrinter =
          printers.where((p) => p.isDefault).firstOrNull ?? printers.firstOrNull;

      if (defaultPrinter == null) {
        emit(const OutputPrintFailed('No printer configured.'));
        return;
      }

      final model = PrinterModel(
        id: defaultPrinter.id,
        name: defaultPrinter.name,
        transport: PrinterTransport.values.firstWhere(
          (t) => t.name == defaultPrinter.transport,
          orElse: () => PrinterTransport.network,
        ),
        address: defaultPrinter.address,
        paperWidthMm: defaultPrinter.paperWidthMm,
        isDefault: defaultPrinter.isDefault,
      );

      await _printerService.printImage(printer: model, imagePath: imagePath);
    } catch (e) {
      emit(OutputPrintFailed(e.toString()));
    }
  }
}
