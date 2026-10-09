import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../models/models.dart';

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
    if (srcImage == null) throw PrinterException('Could not decode image for printing.');

    // 1. Resize to paper width
    final dotsWide = printer.paperWidthMm == 80 ? 576 : 384;
    final scaled   = img.copyResize(srcImage, width: dotsWide);

    // 2. Convert to greyscale + Floyd-Steinberg dither
    final grey     = img.grayscale(scaled);
    final dithered = img.ditherImage(grey, kernel: img.DitherKernel.floydSteinberg, serpentine: false);

    // 3. Encode as ESC/POS raster bytes
    final profile = await CapabilityProfile.load();
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
    final profile = await CapabilityProfile.load();
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
        return UsbPrinterTransport(address: printer.address);
      case PrinterTransport.bluetooth:
        return BluetoothPrinterTransport(address: printer.address);
    }
  }
}

// ─── Transport implementations ───────────────────────────────────────────────

/// Network TCP transport — sends raw bytes to port 9100.
class NetworkPrinterTransport implements PrinterTransportBase {
  final String address; // IP address
  Socket? _socket;

  NetworkPrinterTransport({required this.address});

  @override
  Future<void> sendBytes(Uint8List bytes) async {
    _socket = await Socket.connect(address, 9100,
        timeout: const Duration(seconds: 10));
    _socket!.add(bytes);
    await _socket!.flush();
  }

  @override
  Future<void> close() async => _socket?.destroy();
}

/// USB transport stub — Windows uses spooler raw printing.
/// Replace with your USB library for Android USB Host.
class UsbPrinterTransport implements PrinterTransportBase {
  final String address; // COM port or device path

  UsbPrinterTransport({required this.address});

  @override
  Future<void> sendBytes(Uint8List bytes) async {
    // Windows: write raw bytes to COM port
    final port = File(address);
    await port.writeAsBytes(bytes);
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
    throw PrinterException('Bluetooth printing not yet implemented. Use USB or network.');
  }

  @override
  Future<void> close() async {}
}

class PrinterException implements Exception {
  final String message;
  PrinterException(this.message);
  @override
  String toString() => message;
}
