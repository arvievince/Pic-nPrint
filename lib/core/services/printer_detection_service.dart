import 'dart:io';

/// A printer found by the detection service.
class DetectedPrinter {
  final String name; // Human-readable display name
  final String address; // Port name (USB001, COM3), IP:port, or BT MAC

  const DetectedPrinter({required this.name, required this.address});
}

/// Detects available printers on the host device by transport type.
///
/// USB/System  → Windows print spooler (PowerShell Get-Printer or wmic)
/// Bluetooth   → Windows paired Bluetooth devices via PowerShell / PnP
/// Network     → not auto-detected; user enters IP manually.
class PrinterDetectionService {
  // ─── USB / System Printer Detection (Windows) ──────────────────────────────

  /// Returns all printers installed in the Windows print spooler.
  /// Each entry carries the printer name and its port (USB001, COM3, etc.).
  Future<List<DetectedPrinter>> detectUsbSystemPrinters() async {
    if (!Platform.isWindows) return [];

    try {
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          r"Get-Printer | Select-Object Name, PortName | ConvertTo-Csv -NoTypeInformation",
        ],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        final lines = (result.stdout as String)
            .split('\n')
            .map((l) => l.trim().replaceAll('"', ''))
            .where((l) => l.isNotEmpty)
            .toList();

        final printers = <DetectedPrinter>[];
        for (int i = 1; i < lines.length; i++) {
          final parts = lines[i].split(',');
          if (parts.length >= 2) {
            final name = parts[0].trim();
            final port = parts[1].trim();
            if (name.isNotEmpty && name.toLowerCase() != 'name') {
              printers.add(DetectedPrinter(name: name, address: port.isNotEmpty ? port : name));
            }
          }
        }
        if (printers.isNotEmpty) return printers;
      }
    } catch (_) {}

    try {
      final result = await Process.run(
        'wmic',
        ['printer', 'get', 'Name,PortName', '/format:csv'],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        final lines = (result.stdout as String)
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();

        final printers = <DetectedPrinter>[];
        for (final line in lines) {
          final parts = line.split(',');
          if (parts.length < 3) continue;
          final name = parts[1].trim();
          final port = parts[2].trim();
          if (name.toLowerCase() == 'name' || name.isEmpty) continue;
          printers.add(DetectedPrinter(name: name, address: port.isNotEmpty ? port : name));
        }
        return printers;
      }
    } catch (_) {}

    return [];
  }

  // ─── Bluetooth Device Detection ────────────────────────────────────────────

  /// Returns all Bluetooth devices paired on this device.
  Future<List<DetectedPrinter>> detectBluetoothDevices() async {
    if (Platform.isWindows) {
      return await _detectBluetoothWindows();
    }
    return [];
  }

  Future<List<DetectedPrinter>> _detectBluetoothWindows() async {
    try {
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          r"Get-PnpDevice -Class Bluetooth | Where-Object {$_.Status -eq 'OK'} | Select-Object FriendlyName, DeviceID | ConvertTo-Csv -NoTypeInformation",
        ],
        runInShell: true,
      );

      if (result.exitCode != 0) return [];

      final lines = (result.stdout as String)
          .split('\n')
          .map((l) => l.trim().replaceAll('"', ''))
          .where((l) => l.isNotEmpty)
          .toList();

      final devices = <DetectedPrinter>[];
      for (int i = 1; i < lines.length; i++) {
        final parts = lines[i].split(',');
        if (parts.length < 2) continue;

        final name = parts[0].trim();
        final deviceId = parts[1].trim();

        if (name.isEmpty || name.toLowerCase() == 'friendlyname') continue;

        final macMatch = RegExp(
          r'([0-9A-Fa-f]{2}[_\-]){5}[0-9A-Fa-f]{2}',
        ).firstMatch(deviceId);

        final address = macMatch != null
            ? macMatch.group(0)!.replaceAll('_', ':').toUpperCase()
            : deviceId;

        devices.add(DetectedPrinter(name: name, address: address));
      }

      return devices;
    } catch (_) {
      return [];
    }
  }
}

