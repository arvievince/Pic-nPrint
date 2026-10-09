import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/models.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/printer_service.dart';
import 'output_event.dart';
import 'output_state.dart';

/// Orchestrates the save → upload → print pipeline.
///
/// Pipeline (in order):
///   1. StorageService.saveLocalFiles()  → save composed image locally
///   2. StorageService.uploadToDrive()   → upload to Google Drive (optional)
///   3. PrinterService.printImage()      → send to thermal printer
///
/// The admin setting 'print_without_upload' controls whether step 3
/// waits for step 2 to succeed. If upload fails, OutputUploadFailed is
/// emitted but printing continues if that setting is true.
///
/// After OutputComplete → screen navigates to /qr (if driveUrl exists)
/// or back to /attract (if no Drive configured).
///
class OutputBloc extends Bloc<OutputEvent, OutputState> {
  final StorageService  _storageService;
  final PrinterService  _printerService;
  final AppDatabase     _db;
  final SessionModel    session;

  OutputBloc({
    required StorageService storageService,
    required PrinterService printerService,
    required AppDatabase db,
    required this.session,
  })  : _storageService = storageService,
        _printerService = printerService,
        _db             = db,
        super(const OutputSaving()) {
    on<OutputStarted>(_onStarted);
    on<UploadRetried>(_onUploadRetried);
    on<PrintRequested>(_onPrintRequested);
    on<QrDismissed>(_onQrDismissed);

    // Auto-start the pipeline when the bloc is created
    add(const OutputStarted());
  }

  // ─── Pipeline ─────────────────────────────────────────────────────────────────

  Future<void> _onStarted(
      OutputStarted event, Emitter<OutputState> emit) async {
    // Step 1: Save locally
    emit(const OutputSaving());
    String? localPath;
    try {
      localPath = await _storageService.saveLocalFiles(session);
    } catch (e) {
      // Even if local save fails, continue
    }

    // Step 2: Upload to Drive (optional)
    emit(const OutputUploading());
    String? driveUrl;
    final printWithoutUpload =
        (await _db.getSetting('print_without_upload')) == 'true';

    try {
      driveUrl = await _storageService.uploadToDrive(
        session.copyWith(composedImagePath: localPath),
      );
    } on StorageException catch (e) {
      // Drive not configured — skip QR, continue to print
      if (!e.toString().contains('not configured')) {
        emit(OutputUploadFailed(e.toString()));
        if (!printWithoutUpload) return;
      }
    } catch (e) {
      emit(OutputUploadFailed(e.toString()));
      if (!printWithoutUpload) return;
    }

    // Step 3: Print
    await _doPrint(emit, localPath);

    emit(OutputComplete(driveUrl: driveUrl));
  }

  Future<void> _onUploadRetried(
      UploadRetried event, Emitter<OutputState> emit) async {
    emit(const OutputUploading());
    try {
      final driveUrl = await _storageService.uploadToDrive(session);
      await _doPrint(emit, session.composedImagePath);
      emit(OutputComplete(driveUrl: driveUrl));
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

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Future<void> _doPrint(
      Emitter<OutputState> emit, String? imagePath) async {
    if (imagePath == null) return;

    emit(const OutputPrinting());
    try {
      final printers = await _db.getAllPrinters();
      final defaultPrinter = printers.where((p) => p.isDefault).firstOrNull
          ?? printers.firstOrNull;

      if (defaultPrinter == null) {
        emit(const OutputPrintFailed('No printer configured.'));
        return;
      }

      final model = PrinterModel(
        id:           defaultPrinter.id,
        name:         defaultPrinter.name,
        transport:    PrinterTransport.values.firstWhere(
            (t) => t.name == defaultPrinter.transport),
        address:      defaultPrinter.address,
        paperWidthMm: defaultPrinter.paperWidthMm,
        isDefault:    defaultPrinter.isDefault,
      );

      await _printerService.printImage(printer: model, imagePath: imagePath);
    } catch (e) {
      emit(OutputPrintFailed(e.toString()));
    }
  }
}
