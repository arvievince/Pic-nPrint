import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as img;
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../models/models.dart';
import 'printer_detection_service.dart';

/// Abstract printer transport — implemented by each transport type below.
abstract class PrinterTransportBase {
  Future<void> sendBytes(Uint8List bytes);
  Future<void> close();
}

/// Manages multiple configured printers and dispatches print jobs.
///
/// Flow:
///   OutputBloc.PrintRequested
///     → PrinterService.printImage(session, imagePath)
///       → load default printer from DB / settings
///       → dither image (Floyd-Steinberg) for thermal
///       → encode as ESC/POS raster
///       → send via correct transport
///
class PrinterService {
  CapabilityProfile? _cachedProfile;

  Future<CapabilityProfile> _getProfile() async {
    return _cachedProfile ??= await CapabilityProfile.load();
  }

  /// Print the composed image to the default (or specified) printer.
  ///
  /// Routes automatically by [printer.printerType]:
  /// - [PrinterType.document]: Full-color Windows GDI rendering with paper size
  ///   configuration (Legal, Letter, A4, 4x6, etc.) and guaranteed page ejection.
  /// - [PrinterType.thermal]: Floyd-Steinberg B&W dithering + ESC/POS raster.
  ///
  /// [printer]   The target printer configuration.
  /// [imagePath] Path to the composed image file.
  Future<void> printImage({
    required PrinterModel printer,
    required String imagePath,
    double? targetWidthInches,
    bool alignRight = false,
  }) async {
    final imageBytes = File(imagePath).readAsBytesSync();
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw PrinterException('Could not decode image for printing.');
    }

    // Auto-rotate landscape prints (e.g. horizontal Boarding Pass) 90° CW so
    // they print full-length on thermal rolls and portrait photo paper.
    final srcImage = decoded.width > decoded.height
        ? img.copyRotate(decoded, angle: 90)
        : decoded;

    // Route Document / Color printers to native Windows GDI printing
    if (printer.printerType == PrinterType.document) {
      await _printDocumentImage(
        printer: printer,
        image: srcImage,
        targetWidthInches: targetWidthInches,
        alignRight: alignRight,
      );
      return;
    }

    // 1. Resize to paper width (thermal)
    final dotsWide = printer.paperWidthMm == 80 ? 576 : 384;
    final scaled = img.copyResize(srcImage, width: dotsWide);

    // 2. High-quality B&W filter + Floyd-Steinberg dithering optimized for thermal paper
    final dithered = _ditherForThermal(scaled);

    // 3. Encode as ESC/POS raster bytes
    final profile = await _getProfile();
    final generator = Generator(
      printer.paperWidthMm == 80 ? PaperSize.mm80 : PaperSize.mm58,
      profile,
    );

    List<int> bytes = [];
    bytes += generator.reset();
    bytes += generator.imageRaster(dithered, align: PosAlign.center);
    bytes += generator.feed(3);
    bytes += generator.cut();

    // 4. Send via the correct transport
    final transport = _createTransport(printer);
    try {
      await transport.sendBytes(Uint8List.fromList(bytes));
    } finally {
      await transport.close();
    }
  }

  /// Prints a full-color image to a standard desktop document printer via
  /// native Windows GDI (`gdi32.dll` + `winspool.drv`), applying the configured
  /// paper size (e.g. Legal, Letter, A4) and calling `EndPage`/`EndDoc` so the
  /// printer cleanly ejects the sheet.
  Future<void> _printDocumentImage({
    required PrinterModel printer,
    required img.Image image,
    double? targetWidthInches,
    bool alignRight = false,
    String docName = 'Pic-nPrint Photo',
  }) async {
    if (!Platform.isWindows) {
      throw PrinterException(
        'Document color printing is currently supported on Windows.',
      );
    }

    final candidates = <String>[];
    if (printer.name.trim().isNotEmpty) {
      candidates.add(printer.name.trim());
    }
    if (printer.address.trim().isNotEmpty &&
        printer.address.trim() != printer.name.trim()) {
      candidates.add(printer.address.trim());
    }

    // Also resolve installed Windows printer name in case the saved name/port differs
    try {
      final detected =
          await PrinterDetectionService().detectUsbSystemPrinters();
      for (final p in detected) {
        if (p.address.trim().toLowerCase() ==
                printer.address.trim().toLowerCase() ||
            p.name.trim().toLowerCase() == printer.name.trim().toLowerCase()) {
          if (!candidates.contains(p.name.trim())) {
            candidates.add(p.name.trim());
          }
        }
      }
    } catch (_) {}

    String? lastError;
    for (final candidate in candidates) {
      final error = WindowsGdiPrinter.printImage(
        printerName: candidate,
        image: image,
        paperSize: printer.paperSize,
        targetWidthInches: targetWidthInches,
        alignRight: alignRight,
        docName: docName,
      );
      if (error == null) {
        return; // Success!
      }
      lastError = error;
    }

    throw PrinterException(
      'Failed to print color document to "${printer.name}" '
      '(paper: ${printer.paperSize}).\n'
      '${lastError ?? "Printer could not be opened in Windows."}',
    );
  }

  /// Generates a high-resolution color calibration test page for document printers.
  img.Image _buildDocumentTestPage(PrinterModel printer) {
    const w = 1200;
    const h = 1600;
    final canvas = img.Image(width: w, height: h);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

    // Outer frame border
    img.drawRect(
      canvas,
      x1: 60,
      y1: 60,
      x2: w - 60,
      y2: h - 60,
      color: img.ColorRgb8(30, 30, 30),
      thickness: 6,
    );

    // Header banner
    img.fillRect(
      canvas,
      x1: 66,
      y1: 66,
      x2: w - 66,
      y2: 240,
      color: img.ColorRgb8(25, 25, 28),
    );
    img.drawString(
      canvas,
      'PIC-N-PRINT DOCUMENT TEST PAGE',
      font: img.arial48,
      x: 110,
      y: 125,
      color: img.ColorRgb8(255, 255, 255),
    );

    // Metadata lines
    final now = DateTime.now().toIso8601String().substring(0, 19);
    final lines = [
      'Printer:    ${printer.name}',
      'Mode:       Color Document (Windows GDI)',
      'Paper Size: ${printer.paperSize}',
      'Transport:  ${printer.transport.label}',
      'Timestamp:  $now',
      'Status:     COLOR PRINT & PAGE EJECT OK',
    ];
    int y = 310;
    for (final line in lines) {
      img.drawString(
        canvas,
        line,
        font: img.arial24,
        x: 110,
        y: y,
        color: img.ColorRgb8(30, 30, 30),
      );
      y += 56;
    }

    // Color calibration bars (CMYK + RGB)
    img.drawString(
      canvas,
      'COLOR CALIBRATION SWATCHES',
      font: img.arial24,
      x: 110,
      y: 710,
      color: img.ColorRgb8(60, 60, 60),
    );
    final swatches = <List<int>>[
      [0, 174, 239], // Cyan
      [236, 0, 140], // Magenta
      [255, 242, 0], // Yellow
      [20, 20, 20], // Black
      [230, 57, 70], // Red
      [42, 157, 143], // Green
      [29, 53, 87], // Blue
    ];
    const barTop = 770;
    const barBottom = 1120;
    const marginX = 110;
    final barWidth = ((w - marginX * 2) / swatches.length).floor();
    for (int i = 0; i < swatches.length; i++) {
      final c = swatches[i];
      final x1 = marginX + i * barWidth;
      final x2 = x1 + barWidth - 12;
      img.fillRect(
        canvas,
        x1: x1,
        y1: barTop,
        x2: x2,
        y2: barBottom,
        color: img.ColorRgb8(c[0], c[1], c[2]),
      );
    }

    // Footer confirmation
    img.drawString(
      canvas,
      'If this page printed in color and ejected completely,',
      font: img.arial24,
      x: 110,
      y: 1260,
      color: img.ColorRgb8(40, 40, 40),
    );
    img.drawString(
      canvas,
      'your document printer is configured and ready!',
      font: img.arial24,
      x: 110,
      y: 1310,
      color: img.ColorRgb8(40, 40, 40),
    );

    return canvas;
  }

  /// Print a text-only ticket (e.g. voucher slip).
  Future<void> printText({
    required PrinterModel printer,
    required String text,
  }) async {
    final profile = await _getProfile();
    final generator = Generator(
      printer.paperWidthMm == 80 ? PaperSize.mm80 : PaperSize.mm58,
      profile,
    );

    List<int> bytes = [];
    bytes += generator.reset();
    bytes += generator.text(text);
    bytes += generator.feed(3);
    bytes += generator.cut();

    final transport = _createTransport(printer);
    try {
      await transport.sendBytes(Uint8List.fromList(bytes));
    } finally {
      await transport.close();
    }
  }

  /// Print a formatted voucher ticket slip.
  Future<void> printVoucherSlip({
    required PrinterModel printer,
    required VoucherModel voucher,
    String? kioskTitle,
  }) async {
    final profile = await _getProfile();
    final is80mm = printer.paperWidthMm == 80;
    final paperSize = is80mm ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paperSize, profile);

    final title = (kioskTitle != null && kioskTitle.trim().isNotEmpty)
        ? kioskTitle.trim().toUpperCase()
        : 'PIC & PRINT';
    final divider = '=' * (is80mm ? 48 : 32);

    List<int> bytes = [];
    bytes += generator.reset();
    bytes += generator.text(divider);
    bytes += generator.text(
      title,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    );
    bytes += generator.text(
      'VOUCHER SLIP',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    );
    bytes += generator.text(divider);

    bytes += generator.feed(1);
    bytes += generator.text(
      'CODE:',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text(
      voucher.code,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.feed(1);

    bytes += generator.text(
      'TIER:    ${voucher.shotMode.label} (${voucher.shotMode.photoCount} Photos)',
      styles: const PosStyles(bold: true),
    );
    bytes += generator.text(
      'PRICE:   PHP ${voucher.priceSnapshot.toStringAsFixed(2)}',
      styles: const PosStyles(bold: true),
    );
    final expiryFormatted = voucher.expiresAt.toString().length >= 16
        ? voucher.expiresAt.toString().substring(0, 16)
        : voucher.expiresAt.toString();
    bytes += generator.text('EXPIRES: $expiryFormatted');
    bytes += generator.text(divider);

    bytes += generator.text(
      'Enter this code at the kiosk\nto start your photo session!',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.feed(3);
    bytes += generator.cut();

    final transport = _createTransport(printer);
    try {
      await transport.sendBytes(Uint8List.fromList(bytes));
    } finally {
      await transport.close();
    }
  }

  /// Print a test slip (thermal) or color calibration test page (document)
  /// to verify printer communication and paper ejection.
  Future<void> testPrint(PrinterModel printer) async {
    if (printer.printerType == PrinterType.document) {
      final testImage = _buildDocumentTestPage(printer);
      await _printDocumentImage(
        printer: printer,
        image: testImage,
        targetWidthInches: 4.0,
        docName: 'Pic-nPrint Test Page',
      );
      return;
    }

    final now = DateTime.now();
    final text = '================================\n'
        '       PHOTORECEIPT TEST        \n'
        '================================\n'
        'Printer: ${printer.name}\n'
        'Type:    ${printer.transport.label}\n'
        'Address: ${printer.address}\n'
        'Paper:   ${printer.paperWidthMm}mm\n'
        'Time:    ${now.toIso8601String()}\n'
        'Status:  SUCCESSFUL TEST\n'
        '================================\n\n';
    await printText(printer: printer, text: text);
  }

  PrinterTransportBase _createTransport(PrinterModel printer) {
    switch (printer.transport) {
      case PrinterTransport.network:
        return NetworkPrinterTransport(address: printer.address);
      case PrinterTransport.usb:
        return UsbPrinterTransport(
            name: printer.name, address: printer.address);
      case PrinterTransport.bluetooth:
        return BluetoothPrinterTransport(address: printer.address);
      case PrinterTransport.system:
        return SystemPrinterTransport(
            name: printer.name, address: printer.address);
    }
  }

  /// Converts an image to an optimized 1-bit black & white dithered format
  /// specifically calibrated for thermal receipt printers.
  ///
  /// - Enhances contrast & sharpens contours so eyes, glasses, and face details pop.
  /// - Applies serpentine Floyd-Steinberg error diffusion for smooth photographic shading.
  /// - Protects pure white areas (e.g. Polaroid borders & margins) from dither bleed.
  /// - Outputs standard RGB image (White = 255, Black = 0) with no palette indexing,
  ///   ensuring ESC/POS raster generation leaves white borders completely unburned.
  img.Image _ditherForThermal(img.Image input) {
    final w = input.width;
    final h = input.height;

    // 1. Grayscale conversion
    final grey = img.grayscale(input);

    // 2. Unsharp masking to keep facial features, eyes, glasses, and contours sharp
    final sharpened = img.convolution(grey,
        filter: [
          0,
          -1,
          0,
          -1,
          5,
          -1,
          0,
          -1,
          0,
        ],
        div: 1,
        amount: 0.3);

    // 3. Dynamic range / tone mapping calibrated for thermal paper
    final lum = Float64List(w * h);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final orig = input.getPixel(x, y);
        // Protect pure white border margins from tone shifting
        if (orig.r >= 250 && orig.g >= 250 && orig.b >= 250) {
          lum[y * w + x] = 255.0;
          continue;
        }

        final p = sharpened.getPixel(x, y);
        double val = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b);
        // S-curve & gamma correction to reveal details in skin highlights and clothes
        double norm = val / 255.0;
        norm = (norm - 0.5) * 1.1 + 0.5;
        lum[y * w + x] = (norm * 255.0).clamp(0.0, 255.0);
      }
    }

    // 4. Serpentine Floyd-Steinberg error diffusion
    final out = img.Image(width: w, height: h);
    for (int y = 0; y < h; y++) {
      final leftToRight = (y % 2 == 0);
      final startX = leftToRight ? 0 : w - 1;
      final endX = leftToRight ? w : -1;
      final stepX = leftToRight ? 1 : -1;

      for (int x = startX; x != endX; x += stepX) {
        final idx = y * w + x;

        // Ensure white border margins remain pure white without dither artifacts
        final orig = input.getPixel(x, y);
        if (orig.r >= 254 && orig.g >= 254 && orig.b >= 254) {
          out.setPixelRgb(x, y, 255, 255, 255);
          continue;
        }

        final oldVal = lum[idx];
        final newVal = oldVal < 128.0 ? 0.0 : 255.0;
        final err = oldVal - newVal;

        final colorVal = newVal.toInt();
        out.setPixelRgb(x, y, colorVal, colorVal, colorVal);

        if (leftToRight) {
          if (x + 1 < w) lum[idx + 1] += err * (7.0 / 16.0);
          if (y + 1 < h) {
            if (x - 1 >= 0) lum[idx + w - 1] += err * (3.0 / 16.0);
            lum[idx + w] += err * (5.0 / 16.0);
            if (x + 1 < w) lum[idx + w + 1] += err * (1.0 / 16.0);
          }
        } else {
          if (x - 1 >= 0) lum[idx - 1] += err * (7.0 / 16.0);
          if (y + 1 < h) {
            if (x + 1 < w) lum[idx + w + 1] += err * (3.0 / 16.0);
            lum[idx + w] += err * (5.0 / 16.0);
            if (x - 1 >= 0) lum[idx + w - 1] += err * (1.0 / 16.0);
          }
        }
      }
    }
    return out;
  }
}

// ─── Transport implementations ───────────────────────────────────────────────

/// Network TCP transport — sends raw bytes to port 9100 (or custom port).
class NetworkPrinterTransport implements PrinterTransportBase {
  final String address; // IP address or host:port
  Socket? _socket;

  NetworkPrinterTransport({required this.address});

  @override
  Future<void> sendBytes(Uint8List bytes) async {
    final trimmed = address.trim();
    final colonIndex = trimmed.lastIndexOf(':');
    final String host;
    final int port;
    if (colonIndex != -1 && !trimmed.startsWith('[')) {
      host = trimmed.substring(0, colonIndex);
      port = int.tryParse(trimmed.substring(colonIndex + 1)) ?? 9100;
    } else {
      host = trimmed;
      port = 9100;
    }

    try {
      _socket = await Socket.connect(host, port,
          timeout: const Duration(seconds: 10));
      _socket!.add(bytes);
      await _socket!.flush();
    } on SocketException catch (e) {
      throw PrinterException(
          'Failed to connect to printer at $host:$port: ${e.message}');
    } catch (e) {
      throw PrinterException('Printer communication error ($host:$port): $e');
    }
  }

  @override
  Future<void> close() async {
    if (_socket != null) {
      try {
        await _socket!.close();
      } catch (_) {
        _socket?.destroy();
      }
      _socket = null;
    }
  }
}

/// USB transport — sends raw ESC/POS bytes to Windows printer via winspool spooler,
/// or serial COM port fallback.
class UsbPrinterTransport implements PrinterTransportBase {
  final String name; // Configured printer name (e.g. "XP-90")
  final String address; // Port or identifier (e.g. "USB001", "COM3")

  UsbPrinterTransport({required this.name, required this.address});

  @override
  Future<void> sendBytes(Uint8List bytes) async {
    if (Platform.isWindows) {
      // 1. Try Windows Print Spooler with the printer name (e.g. "XP-90")
      if (name.isNotEmpty && WindowsRawSpooler.sendRawBytes(name, bytes)) {
        return;
      }

      // 2. Try Windows Print Spooler with address (in case user stored the printer name in address)
      if (address.isNotEmpty &&
          address != name &&
          WindowsRawSpooler.sendRawBytes(address, bytes)) {
        return;
      }

      // 3. Look up if address matches any installed printer port (e.g. "USB001" -> "XP-90")
      try {
        final detected =
            await PrinterDetectionService().detectUsbSystemPrinters();
        for (final p in detected) {
          if (p.address.trim().toLowerCase() == address.trim().toLowerCase() ||
              p.name.trim().toLowerCase() == name.trim().toLowerCase()) {
            if (WindowsRawSpooler.sendRawBytes(p.name, bytes)) {
              return;
            }
          }
        }
      } catch (_) {}

      // 4. Serial COM port fallback (e.g. "\\.\COM3")
      if (address.toUpperCase().startsWith('COM')) {
        try {
          final portName = address.startsWith(r'\\.\')
              ? address
              : r'\\.\' + address.toUpperCase();
          final port = File(portName);
          await port.writeAsBytes(bytes);
          return;
        } catch (_) {}
      }

      throw PrinterException(
        'Failed to send print job to Windows USB printer "$name" (port: $address).\n'
        'Please check that:\n'
        '1. The printer is powered on and connected via USB.\n'
        '2. The printer driver is installed in Windows Settings > Bluetooth & Devices > Printers.\n'
        '3. The printer name matches the installed name in Windows.',
      );
    } else {
      throw PrinterException(
        'Direct USB thermal printing is currently supported on Windows. '
        'On Android, please use a Network (TCP/IP) or Bluetooth thermal printer.',
      );
    }
  }

  @override
  Future<void> close() async {}
}

/// Bluetooth transport stub — add flutter_bluetooth_serial or similar.
class BluetoothPrinterTransport implements PrinterTransportBase {
  final String address; // BT MAC address

  BluetoothPrinterTransport({required this.address});

  @override
  Future<void> sendBytes(Uint8List bytes) async {
    // TODO: integrate flutter_bluetooth_serial or print_bluetooth_thermal
    throw PrinterException(
        'Bluetooth printing not yet implemented. Use USB or network.');
  }

  @override
  Future<void> close() async {}
}

/// System / OS installed printer transport — sends raw ESC/POS bytes via Windows print spooler.
class SystemPrinterTransport implements PrinterTransportBase {
  final String name;
  final String address;

  SystemPrinterTransport({required this.name, required this.address});

  @override
  Future<void> sendBytes(Uint8List bytes) async {
    if (Platform.isWindows) {
      if (name.isNotEmpty && WindowsRawSpooler.sendRawBytes(name, bytes)) {
        return;
      }
      if (address.isNotEmpty &&
          address != name &&
          WindowsRawSpooler.sendRawBytes(address, bytes)) {
        return;
      }
      try {
        final detected =
            await PrinterDetectionService().detectUsbSystemPrinters();
        for (final p in detected) {
          if (p.address.trim().toLowerCase() == address.trim().toLowerCase() ||
              p.name.trim().toLowerCase() == name.trim().toLowerCase()) {
            if (WindowsRawSpooler.sendRawBytes(p.name, bytes)) {
              return;
            }
          }
        }
      } catch (_) {}
      throw PrinterException(
        'Failed to send print job to Windows printer "$name" (port: $address).',
      );
    } else {
      throw PrinterException(
        'System printer transport is only supported on Windows.',
      );
    }
  }

  @override
  Future<void> close() async {}
}

// ─── Windows Win32 Print Spooler (RAW ESC/POS Dispatcher) ───────────────────

final class _DocInfo1W extends Struct {
  external Pointer<Utf16> pDocName;
  external Pointer<Utf16> pOutputFile;
  external Pointer<Utf16> pDatatype;
}

typedef _OpenPrinterWNative = Int32 Function(
  Pointer<Utf16> pPrinterName,
  Pointer<IntPtr> phPrinter,
  Pointer<Void> pDefault,
);
typedef _OpenPrinterWDart = int Function(
  Pointer<Utf16> pPrinterName,
  Pointer<IntPtr> phPrinter,
  Pointer<Void> pDefault,
);

typedef _StartDocPrinterWNative = Int32 Function(
  IntPtr hPrinter,
  Uint32 level,
  Pointer<_DocInfo1W> pDocInfo,
);
typedef _StartDocPrinterWDart = int Function(
  int hPrinter,
  int level,
  Pointer<_DocInfo1W> pDocInfo,
);

typedef _StartPagePrinterNative = Int32 Function(IntPtr hPrinter);
typedef _StartPagePrinterDart = int Function(int hPrinter);

typedef _WritePrinterNative = Int32 Function(
  IntPtr hPrinter,
  Pointer<Void> pBuf,
  Uint32 cbBuf,
  Pointer<Uint32> pcWritten,
);
typedef _WritePrinterDart = int Function(
  int hPrinter,
  Pointer<Void> pBuf,
  int cbBuf,
  Pointer<Uint32> pcWritten,
);

typedef _EndPagePrinterNative = Int32 Function(IntPtr hPrinter);
typedef _EndPagePrinterDart = int Function(int hPrinter);

typedef _EndDocPrinterNative = Int32 Function(IntPtr hPrinter);
typedef _EndDocPrinterDart = int Function(int hPrinter);

typedef _ClosePrinterNative = Int32 Function(IntPtr hPrinter);
typedef _ClosePrinterDart = int Function(int hPrinter);

/// Directly spools raw bytes (ESC/POS or binary) to a named Windows printer
/// using the native Win32 `winspool.drv` print spooler API.
class WindowsRawSpooler {
  static bool sendRawBytes(
    String printerName,
    Uint8List bytes, {
    String docName = 'Pic-nPrint RAW Job',
  }) {
    if (!Platform.isWindows || bytes.isEmpty) return false;

    DynamicLibrary winspool;
    try {
      winspool = DynamicLibrary.open('winspool.drv');
    } catch (_) {
      return false;
    }

    final openPrinter = winspool
        .lookupFunction<_OpenPrinterWNative, _OpenPrinterWDart>('OpenPrinterW');
    final startDocPrinter =
        winspool.lookupFunction<_StartDocPrinterWNative, _StartDocPrinterWDart>(
            'StartDocPrinterW');
    final startPagePrinter =
        winspool.lookupFunction<_StartPagePrinterNative, _StartPagePrinterDart>(
            'StartPagePrinter');
    final writePrinter = winspool
        .lookupFunction<_WritePrinterNative, _WritePrinterDart>('WritePrinter');
    final endPagePrinter =
        winspool.lookupFunction<_EndPagePrinterNative, _EndPagePrinterDart>(
            'EndPagePrinter');
    final endDocPrinter =
        winspool.lookupFunction<_EndDocPrinterNative, _EndDocPrinterDart>(
            'EndDocPrinter');
    final closePrinter = winspool
        .lookupFunction<_ClosePrinterNative, _ClosePrinterDart>('ClosePrinter');

    final pPrinterName = printerName.toNativeUtf16();
    final phPrinter = calloc<IntPtr>();

    try {
      final openRes = openPrinter(pPrinterName, phPrinter, nullptr);
      if (openRes == 0) {
        return false;
      }
      final hPrinter = phPrinter.value;

      final pDocInfo = calloc<_DocInfo1W>();
      final pDocNameStr = docName.toNativeUtf16();
      final pDataTypeStr = 'RAW'.toNativeUtf16();

      pDocInfo.ref.pDocName = pDocNameStr;
      pDocInfo.ref.pOutputFile = nullptr;
      pDocInfo.ref.pDatatype = pDataTypeStr;

      try {
        final docId = startDocPrinter(hPrinter, 1, pDocInfo);
        if (docId <= 0) {
          return false;
        }

        try {
          startPagePrinter(hPrinter);

          final pBuf = calloc<Uint8>(bytes.length);
          pBuf.asTypedList(bytes.length).setAll(0, bytes);
          final pWritten = calloc<Uint32>();

          try {
            writePrinter(hPrinter, pBuf.cast(), bytes.length, pWritten);
          } finally {
            calloc.free(pBuf);
            calloc.free(pWritten);
          }

          endPagePrinter(hPrinter);
        } finally {
          endDocPrinter(hPrinter);
        }
      } finally {
        calloc.free(pDocNameStr);
        calloc.free(pDataTypeStr);
        calloc.free(pDocInfo);
        closePrinter(hPrinter);
      }

      return true;
    } finally {
      calloc.free(pPrinterName);
      calloc.free(phPrinter);
    }
  }
}

class PrinterException implements Exception {
  final String message;
  PrinterException(this.message);
  @override
  String toString() => message;
}

// ─── Windows Win32 GDI Color Document Printer ───────────────────────────────

final class _DocInfoW extends Struct {
  @Int32()
  external int cbSize;
  external Pointer<Utf16> lpszDocName;
  external Pointer<Utf16> lpszOutput;
  external Pointer<Utf16> lpszDatatype;
  @Uint32()
  external int fwType;
}

final class _BitmapInfoHeader extends Struct {
  @Uint32()
  external int biSize;
  @Int32()
  external int biWidth;
  @Int32()
  external int biHeight;
  @Uint16()
  external int biPlanes;
  @Uint16()
  external int biBitCount;
  @Uint32()
  external int biCompression;
  @Uint32()
  external int biSizeImage;
  @Int32()
  external int biXPelsPerMeter;
  @Int32()
  external int biYPelsPerMeter;
  @Uint32()
  external int biClrUsed;
  @Uint32()
  external int biClrImportant;
}

final class _BitmapInfo extends Struct {
  external _BitmapInfoHeader bmiHeader;
  @Uint32()
  external int bmiColors;
}

typedef _CreateDCWNative = IntPtr Function(
  Pointer<Utf16> pwszDriver,
  Pointer<Utf16> pwszDevice,
  Pointer<Utf16> pszPort,
  Pointer<Void> pdm,
);
typedef _CreateDCWDart = int Function(
  Pointer<Utf16> pwszDriver,
  Pointer<Utf16> pwszDevice,
  Pointer<Utf16> pszPort,
  Pointer<Void> pdm,
);

typedef _DeleteDCNative = Int32 Function(IntPtr hdc);
typedef _DeleteDCDart = int Function(int hdc);

typedef _GetDeviceCapsNative = Int32 Function(IntPtr hdc, Int32 index);
typedef _GetDeviceCapsDart = int Function(int hdc, int index);

typedef _SetStretchBltModeNative = Int32 Function(IntPtr hdc, Int32 mode);
typedef _SetStretchBltModeDart = int Function(int hdc, int mode);

typedef _SetBrushOrgExNative = Int32 Function(
  IntPtr hdc,
  Int32 x,
  Int32 y,
  Pointer<Void> lppt,
);
typedef _SetBrushOrgExDart = int Function(
  int hdc,
  int x,
  int y,
  Pointer<Void> lppt,
);

typedef _StartDocWNative = Int32 Function(
  IntPtr hdc,
  Pointer<_DocInfoW> lpdi,
);
typedef _StartDocWDart = int Function(
  int hdc,
  Pointer<_DocInfoW> lpdi,
);

typedef _EndDocNative = Int32 Function(IntPtr hdc);
typedef _EndDocDart = int Function(int hdc);

typedef _StartPageNative = Int32 Function(IntPtr hdc);
typedef _StartPageDart = int Function(int hdc);

typedef _EndPageNative = Int32 Function(IntPtr hdc);
typedef _EndPageDart = int Function(int hdc);

typedef _StretchDIBitsNative = Int32 Function(
  IntPtr hdc,
  Int32 xDest,
  Int32 yDest,
  Int32 destWidth,
  Int32 destHeight,
  Int32 xSrc,
  Int32 ySrc,
  Int32 srcWidth,
  Int32 srcHeight,
  Pointer<Void> lpBits,
  Pointer<_BitmapInfo> lpbmi,
  Uint32 iUsage,
  Uint32 rop,
);
typedef _StretchDIBitsDart = int Function(
  int hdc,
  int xDest,
  int yDest,
  int destWidth,
  int destHeight,
  int xSrc,
  int ySrc,
  int srcWidth,
  int srcHeight,
  Pointer<Void> lpBits,
  Pointer<_BitmapInfo> lpbmi,
  int iUsage,
  int rop,
);

typedef _DocumentPropertiesWNative = Int32 Function(
  IntPtr hWnd,
  IntPtr hPrinter,
  Pointer<Utf16> pDeviceName,
  Pointer<Void> pDevModeOutput,
  Pointer<Void> pDevModeInput,
  Uint32 fMode,
);
typedef _DocumentPropertiesWDart = int Function(
  int hWnd,
  int hPrinter,
  Pointer<Utf16> pDeviceName,
  Pointer<Void> pDevModeOutput,
  Pointer<Void> pDevModeInput,
  int fMode,
);

/// Prints full-color images to standard Windows desktop/document printers
/// (Brother, Epson, HP, Canon, etc.) via native Win32 GDI (`gdi32.dll`)
/// and `winspool.drv` (`DocumentPropertiesW`).
///
/// Guarantees:
/// - True 32-bit RGB color rendering (no thermal B&W dithering or ESC/POS raw text)
/// - Explicit paper size selection (Legal, Letter, A4, A6, 4x6, 5x7, etc.) via `DEVMODEW`
/// - High-quality `HALFTONE` bicubic/bilinear scaling preserving exact aspect ratio
/// - Proper `EndPage` / `EndDoc` calls so the printer always feeds and ejects the sheet
class WindowsGdiPrinter {
  // GetDeviceCaps indices
  static const int _horzRes = 8;
  static const int _vertRes = 10;
  static const int _logPixelsX = 88;

  // StretchBlt modes & ROP
  static const int _halftone = 4;
  static const int _dibRgbColors = 0;
  static const int _srcCopy = 0x00CC0020;

  // DocumentPropertiesW flags
  static const int _dmOutBuffer = 2;
  static const int _dmInBuffer = 8;

  // DEVMODEW byte offsets (Windows ABI, fixed for Unicode DEVMODEW)
  static const int _dmFieldsOffset = 72; // DWORD (4 bytes)
  static const int _dmOrientationOffset = 76; // short (2 bytes)
  static const int _dmPaperSizeOffset = 78; // short (2 bytes)
  static const int _dmPaperLengthOffset = 80; // short (2 bytes, tenths of mm)
  static const int _dmPaperWidthOffset = 82; // short (2 bytes, tenths of mm)
  static const int _dmColorOffset = 92; // short (2 bytes)

  // DEVMODEW dmFields bitmasks
  static const int _dmOrientation = 0x00000001;
  static const int _dmPaperSize = 0x00000002;
  static const int _dmPaperLength = 0x00000004;
  static const int _dmPaperWidth = 0x00000008;
  static const int _dmColor = 0x00000800;

  // Orientation & Color constants
  static const int _dmOrientPortrait = 1;
  static const int _dmColorColor = 2;

  /// Maps configured paper size string to Windows `DMPAPER_*` code,
  /// or returns 0 for custom photo dimensions.
  static int _paperSizeCode(String paperSize) {
    switch (paperSize.toLowerCase().trim()) {
      case 'letter':
        return 1; // DMPAPER_LETTER (8.5 x 11 in)
      case 'legal':
        return 5; // DMPAPER_LEGAL (8.5 x 14 in)
      case 'a4':
        return 9; // DMPAPER_A4 (210 x 297 mm)
      case 'a6':
        return 70; // DMPAPER_A6 (105 x 148 mm)
      default:
        return 0;
    }
  }

  /// Returns `(widthTenthsMm, heightTenthsMm)` for custom photo paper sizes,
  /// or `null` when using a standard `DMPAPER_*` code.
  static (int, int)? _customPaperTenthsMm(String paperSize) {
    switch (paperSize.toLowerCase().trim()) {
      case '4x6':
        return (1016, 1524); // 4 x 6 in
      case '5x7':
        return (1270, 1778); // 5 x 7 in
      case '2x6':
        return (508, 1524); // 2 x 6 in
      case 'square4x4':
        return (1016, 1016); // 4 x 4 in
      default:
        return null;
    }
  }

  /// Prints [image] in full color to [printerName] on [paperSize].
  /// Returns `null` on success, or an error description string on failure.
  static String? printImage({
    required String printerName,
    required img.Image image,
    required String paperSize,
    double? targetWidthInches,
    bool alignRight = false,
    String docName = 'Pic-nPrint Photo',
  }) {
    if (!Platform.isWindows) {
      return 'Windows GDI printing is only supported on Windows.';
    }

    final DynamicLibrary gdi32;
    final DynamicLibrary winspool;
    try {
      gdi32 = DynamicLibrary.open('gdi32.dll');
      winspool = DynamicLibrary.open('winspool.drv');
    } catch (e) {
      return 'Failed to load Windows printing libraries: $e';
    }

    final createDCW =
        gdi32.lookupFunction<_CreateDCWNative, _CreateDCWDart>('CreateDCW');
    final deleteDC =
        gdi32.lookupFunction<_DeleteDCNative, _DeleteDCDart>('DeleteDC');
    final getDeviceCaps =
        gdi32.lookupFunction<_GetDeviceCapsNative, _GetDeviceCapsDart>(
            'GetDeviceCaps');
    final setStretchBltMode =
        gdi32.lookupFunction<_SetStretchBltModeNative, _SetStretchBltModeDart>(
            'SetStretchBltMode');
    final setBrushOrgEx =
        gdi32.lookupFunction<_SetBrushOrgExNative, _SetBrushOrgExDart>(
            'SetBrushOrgEx');
    final startDocW =
        gdi32.lookupFunction<_StartDocWNative, _StartDocWDart>('StartDocW');
    final endDoc = gdi32.lookupFunction<_EndDocNative, _EndDocDart>('EndDoc');
    final startPage =
        gdi32.lookupFunction<_StartPageNative, _StartPageDart>('StartPage');
    final endPage =
        gdi32.lookupFunction<_EndPageNative, _EndPageDart>('EndPage');
    final stretchDIBits =
        gdi32.lookupFunction<_StretchDIBitsNative, _StretchDIBitsDart>(
            'StretchDIBits');

    final openPrinter = winspool
        .lookupFunction<_OpenPrinterWNative, _OpenPrinterWDart>('OpenPrinterW');
    final closePrinter = winspool
        .lookupFunction<_ClosePrinterNative, _ClosePrinterDart>('ClosePrinter');
    final documentProperties = winspool.lookupFunction<
        _DocumentPropertiesWNative,
        _DocumentPropertiesWDart>('DocumentPropertiesW');

    final pDriver = 'WINSPOOL'.toNativeUtf16();
    final pPrinterName = printerName.toNativeUtf16();
    Pointer<Uint8> pDevModeBuf = nullptr;
    int hdc = 0;

    try {
      // 1. Attempt to obtain & configure DEVMODEW (paper size, portrait, color)
      pDevModeBuf = _buildConfiguredDevMode(
        pPrinterName: pPrinterName,
        paperSize: paperSize,
        openPrinter: openPrinter,
        closePrinter: closePrinter,
        documentProperties: documentProperties,
      );

      // 2. Create Printer Device Context (with configured DEVMODEW if available)
      hdc = createDCW(
        pDriver,
        pPrinterName,
        nullptr,
        pDevModeBuf != nullptr ? pDevModeBuf.cast<Void>() : nullptr,
      );
      if (hdc == 0 && pDevModeBuf != nullptr) {
        // Fallback: retry with driver defaults if custom DEVMODEW was rejected
        hdc = createDCW(pDriver, pPrinterName, nullptr, nullptr);
      }
      if (hdc == 0) {
        return 'Could not create printer device context for "$printerName".';
      }

      // 3. Query printable area dimensions in device pixels
      final pageW = getDeviceCaps(hdc, _horzRes);
      final pageH = getDeviceCaps(hdc, _vertRes);
      if (pageW <= 0 || pageH <= 0) {
        return 'Invalid printable dimensions (${pageW}x$pageH) reported by "$printerName".';
      }

      // 4. Start Print Job
      final pDocInfo = calloc<_DocInfoW>();
      final pDocName = docName.toNativeUtf16();
      pDocInfo.ref.cbSize = sizeOf<_DocInfoW>();
      pDocInfo.ref.lpszDocName = pDocName;
      pDocInfo.ref.lpszOutput = nullptr;
      pDocInfo.ref.lpszDatatype = nullptr;
      pDocInfo.ref.fwType = 0;

      try {
        final jobId = startDocW(hdc, pDocInfo);
        if (jobId <= 0) {
          return 'StartDocW failed for "$printerName" (code: $jobId).';
        }

        try {
          final pageRes = startPage(hdc);
          if (pageRes <= 0) {
            return 'StartPage failed for "$printerName" (code: $pageRes).';
          }

          try {
            // Enable high-quality HALFTONE photographic resampling
            setStretchBltMode(hdc, _halftone);
            setBrushOrgEx(hdc, 0, 0, nullptr);

            final fixedSize = targetWidthInches != null && targetWidthInches > 0;
            final dpiForMargin = getDeviceCaps(hdc, _logPixelsX);
            // Fixed-size prints use a tight 0.15 in margin (corner placement);
            // fit-to-page prints keep the 3% safety margin.
            final marginX = fixedSize
                ? (0.15 * (dpiForMargin > 0 ? dpiForMargin : 300)).round()
                : (pageW * 0.03).round();
            final marginY = fixedSize
                ? (0.15 * (dpiForMargin > 0 ? dpiForMargin : 300)).round()
                : (pageH * 0.03).round();
            final availW = (pageW - marginX * 2).clamp(1, pageW);
            final availH = (pageH - marginY * 2).clamp(1, pageH);

            final imgAspect = image.width / image.height;
            final availAspect = availW / availH;

            int destW;
            int destH;
            int destX;
            int destY;
            if (targetWidthInches != null && targetWidthInches > 0) {
              // Fixed physical size: inches × printer DPI, aspect preserved.
              final dpiX = getDeviceCaps(hdc, _logPixelsX);
              destW = (targetWidthInches * (dpiX > 0 ? dpiX : 300)).round();
              destH = (destW / imgAspect).round();
              // Safety clamp: shrink proportionally if larger than printable area.
              if (destW > availW || destH > availH) {
                final scale = [availW / destW, availH / destH]
                    .reduce((a, b) => a < b ? a : b);
                destW = (destW * scale).round();
                destH = (destH * scale).round();
              }
              destW = destW.clamp(1, availW);
              destH = destH.clamp(1, availH);
              // Top-left (or top-right) corner, single copy — saves paper.
              destX = alignRight
                  ? pageW - marginX - destW
                  : marginX;
              destY = marginY;
            } else {
              // Fit-to-page (used by admin test pages).
              if (imgAspect > availAspect) {
                destW = availW;
                destH = (availW / imgAspect).round().clamp(1, availH);
              } else {
                destH = availH;
                destW = (availH * imgAspect).round().clamp(1, availW);
              }
              destX = marginX + ((availW - destW) ~/ 2);
              destY = marginY + ((availH - destH) ~/ 2);
            }

            // Convert image to top-down 32-bit BGRA buffer (composited over white)
            final pixelCount = image.width * image.height;
            final byteLen = pixelCount * 4;
            final pPixels = calloc<Uint8>(byteLen);
            final pBmi = calloc<_BitmapInfo>();

            try {
              final dst = pPixels.asTypedList(byteLen);
              int offset = 0;
              for (int y = 0; y < image.height; y++) {
                for (int x = 0; x < image.width; x++) {
                  final p = image.getPixel(x, y);
                  final a = p.a.toInt();
                  int r = p.r.toInt();
                  int g = p.g.toInt();
                  int b = p.b.toInt();
                  if (a < 255) {
                    // Alpha-blend over pure white paper
                    final alpha = a / 255.0;
                    final inv = 1.0 - alpha;
                    r = (r * alpha + 255.0 * inv).round().clamp(0, 255);
                    g = (g * alpha + 255.0 * inv).round().clamp(0, 255);
                    b = (b * alpha + 255.0 * inv).round().clamp(0, 255);
                  }
                  dst[offset++] = b;
                  dst[offset++] = g;
                  dst[offset++] = r;
                  dst[offset++] = 255;
                }
              }

              pBmi.ref.bmiHeader.biSize = sizeOf<_BitmapInfoHeader>();
              pBmi.ref.bmiHeader.biWidth = image.width;
              // Negative biHeight specifies a top-down DIB (origin at top-left)
              pBmi.ref.bmiHeader.biHeight = -image.height;
              pBmi.ref.bmiHeader.biPlanes = 1;
              pBmi.ref.bmiHeader.biBitCount = 32;
              pBmi.ref.bmiHeader.biCompression = 0; // BI_RGB
              pBmi.ref.bmiHeader.biSizeImage = byteLen;
              pBmi.ref.bmiHeader.biXPelsPerMeter = 0;
              pBmi.ref.bmiHeader.biYPelsPerMeter = 0;
              pBmi.ref.bmiHeader.biClrUsed = 0;
              pBmi.ref.bmiHeader.biClrImportant = 0;
              pBmi.ref.bmiColors = 0;

              final drawn = stretchDIBits(
                hdc,
                destX,
                destY,
                destW,
                destH,
                0,
                0,
                image.width,
                image.height,
                pPixels.cast<Void>(),
                pBmi,
                _dibRgbColors,
                _srcCopy,
              );
              if (drawn <= 0) {
                return 'StretchDIBits failed while drawing to "$printerName".';
              }
            } finally {
              calloc.free(pPixels);
              calloc.free(pBmi);
            }
          } finally {
            // Crucial: EndPage instructs the printer driver to feed and eject the sheet
            endPage(hdc);
          }
        } finally {
          // Crucial: EndDoc completes and flushes the print job cleanly
          endDoc(hdc);
        }
      } finally {
        calloc.free(pDocName);
        calloc.free(pDocInfo);
      }

      return null; // Success
    } finally {
      if (hdc != 0) {
        deleteDC(hdc);
      }
      if (pDevModeBuf != nullptr) {
        calloc.free(pDevModeBuf);
      }
      calloc.free(pDriver);
      calloc.free(pPrinterName);
    }
  }

  /// Queries the printer's default `DEVMODEW` via `DocumentPropertiesW`,
  /// applies the requested paper size, portrait orientation, and full-color mode,
  /// and validates it back through the driver.
  ///
  /// Caller is responsible for freeing the returned pointer if non-null.
  static Pointer<Uint8> _buildConfiguredDevMode({
    required Pointer<Utf16> pPrinterName,
    required String paperSize,
    required _OpenPrinterWDart openPrinter,
    required _ClosePrinterDart closePrinter,
    required _DocumentPropertiesWDart documentProperties,
  }) {
    final phPrinter = calloc<IntPtr>();
    try {
      if (openPrinter(pPrinterName, phPrinter, nullptr) == 0) {
        return nullptr;
      }
      final hPrinter = phPrinter.value;
      try {
        // Query required buffer size (includes driver-private extra data)
        final needed = documentProperties(
          0,
          hPrinter,
          pPrinterName,
          nullptr,
          nullptr,
          0,
        );
        if (needed <= 0) return nullptr;

        final buf = calloc<Uint8>(needed);
        final resGet = documentProperties(
          0,
          hPrinter,
          pPrinterName,
          buf.cast<Void>(),
          nullptr,
          _dmOutBuffer,
        );
        if (resGet <= 0) {
          calloc.free(buf);
          return nullptr;
        }

        // Modify DEVMODEW fields safely using ByteData view over the buffer
        final bytes = buf.asTypedList(needed);
        final view = ByteData.sublistView(bytes);

        int fields = view.getUint32(_dmFieldsOffset, Endian.little);

        // Always request Portrait orientation & Full Color mode
        fields |= _dmOrientation | _dmColor;
        view.setInt16(_dmOrientationOffset, _dmOrientPortrait, Endian.little);
        view.setInt16(_dmColorOffset, _dmColorColor, Endian.little);

        final stdCode = _paperSizeCode(paperSize);
        if (stdCode > 0) {
          fields |= _dmPaperSize;
          fields &= ~(_dmPaperWidth | _dmPaperLength);
          view.setInt16(_dmPaperSizeOffset, stdCode, Endian.little);
        } else {
          final custom = _customPaperTenthsMm(paperSize);
          if (custom != null) {
            fields |= _dmPaperSize | _dmPaperWidth | _dmPaperLength;
            view.setInt16(_dmPaperSizeOffset, 0, Endian.little);
            view.setInt16(_dmPaperWidthOffset, custom.$1, Endian.little);
            view.setInt16(_dmPaperLengthOffset, custom.$2, Endian.little);
          }
        }

        view.setUint32(_dmFieldsOffset, fields, Endian.little);

        // Validate & merge modified DEVMODEW with the printer driver
        documentProperties(
          0,
          hPrinter,
          pPrinterName,
          buf.cast<Void>(),
          buf.cast<Void>(),
          _dmInBuffer | _dmOutBuffer,
        );

        return buf;
      } finally {
        closePrinter(hPrinter);
      }
    } finally {
      calloc.free(phPrinter);
    }
  }
}
