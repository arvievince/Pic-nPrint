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
  /// [printer]   The target printer configuration.
  /// [imagePath] Path to the composed image file.
  Future<void> printImage({
    required PrinterModel printer,
    required String imagePath,
  }) async {
    final imageBytes = File(imagePath).readAsBytesSync();
    final srcImage = img.decodeImage(imageBytes);
    if (srcImage == null) {
      throw PrinterException('Could not decode image for printing.');
    }

    // 1. Resize to paper width
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

  /// Print a test slip to verify printer communication.
  Future<void> testPrint(PrinterModel printer) async {
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
        return UsbPrinterTransport(name: printer.name, address: printer.address);
      case PrinterTransport.bluetooth:
        return BluetoothPrinterTransport(address: printer.address);
      case PrinterTransport.system:
        return SystemPrinterTransport(name: printer.name, address: printer.address);
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
        final detected = await PrinterDetectionService().detectUsbSystemPrinters();
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
        final detected = await PrinterDetectionService().detectUsbSystemPrinters();
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
    final startDocPrinter = winspool
        .lookupFunction<_StartDocPrinterWNative, _StartDocPrinterWDart>(
            'StartDocPrinterW');
    final startPagePrinter = winspool
        .lookupFunction<_StartPagePrinterNative, _StartPagePrinterDart>(
            'StartPagePrinter');
    final writePrinter = winspool
        .lookupFunction<_WritePrinterNative, _WritePrinterDart>('WritePrinter');
    final endPagePrinter = winspool
        .lookupFunction<_EndPagePrinterNative, _EndPagePrinterDart>(
            'EndPagePrinter');
    final endDocPrinter = winspool
        .lookupFunction<_EndDocPrinterNative, _EndDocPrinterDart>('EndDocPrinter');
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
