import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import '../models/models.dart';

class ExcelExportService {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  static final DateFormat _fileTimestamp = DateFormat('yyyyMMdd_HHmmss');

  /// Exports a list of newly generated [VoucherModel] vouchers to Excel.
  static Future<String?> exportVoucherBatch(List<VoucherModel> vouchers) async {
    if (vouchers.isEmpty) return null;

    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    final sheetName = 'Generated Vouchers';
    excel.rename(defaultSheet ?? 'Sheet1', sheetName);
    final sheet = excel[sheetName];

    // Header styling
    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#1E293B'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final headers = [
      'Voucher Code',
      'Tier Mode',
      'Price (PHP)',
      'Serial Number',
      'Location ID',
      'Expires At',
    ];

    for (var col = 0; col < headers.length; col++) {
      final cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = headerStyle;
    }

    final dataStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
    final numberStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );

    for (var r = 0; r < vouchers.length; r++) {
      final v = vouchers[r];
      final rowIdx = r + 1;

      _setCell(sheet, 0, rowIdx, TextCellValue(v.code), dataStyle);
      _setCell(sheet, 1, rowIdx, TextCellValue(v.shotMode.label), dataStyle);
      _setCell(sheet, 2, rowIdx, DoubleCellValue(v.priceSnapshot), numberStyle);
      _setCell(sheet, 3, rowIdx, TextCellValue(v.serial), dataStyle);
      _setCell(sheet, 4, rowIdx, TextCellValue(v.locationId), dataStyle);
      _setCell(sheet, 5, rowIdx, TextCellValue(_dateFormat.format(v.expiresAt)),
          dataStyle);
    }

    _autoFitColumns(sheet, headers.length);

    final modeLabel = vouchers.first.shotMode.name;
    final defaultFileName =
        'vouchers_${modeLabel}_${_fileTimestamp.format(DateTime.now())}.xlsx';
    return await _saveWorkbook(excel, defaultFileName);
  }

  /// Exports voucher records from the inventory table.
  static Future<String?> exportVouchersInventory(
    List<VoucherEntry> vouchers, {
    String filterLabel = 'Inventory',
  }) async {
    if (vouchers.isEmpty) return null;

    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    final sheetName = 'Vouchers';
    excel.rename(defaultSheet ?? 'Sheet1', sheetName);
    final sheet = excel[sheetName];

    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#1E293B'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final headers = [
      'Voucher Code',
      'Tier Mode',
      'Price (PHP)',
      'Status',
      'Serial Number',
      'Location ID',
      'Created Date',
      'Expires At',
      'Redeemed At',
      'Void Reason',
    ];

    for (var col = 0; col < headers.length; col++) {
      final cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = headerStyle;
    }

    final dataStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
    final numberStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );

    for (var r = 0; r < vouchers.length; r++) {
      final v = vouchers[r];
      final rowIdx = r + 1;
      final mode = ShotModeExtension.fromTierChar(v.tierChar);

      _setCell(sheet, 0, rowIdx, TextCellValue(v.code), dataStyle);
      _setCell(sheet, 1, rowIdx, TextCellValue(mode.label), dataStyle);
      _setCell(sheet, 2, rowIdx, DoubleCellValue(v.priceSnapshot), numberStyle);
      _setCell(
          sheet, 3, rowIdx, TextCellValue(v.status.toUpperCase()), dataStyle);
      _setCell(sheet, 4, rowIdx, TextCellValue(v.serial), dataStyle);
      _setCell(sheet, 5, rowIdx, TextCellValue(v.locationId), dataStyle);
      _setCell(sheet, 6, rowIdx, TextCellValue(_dateFormat.format(v.createdAt)),
          dataStyle);
      _setCell(sheet, 7, rowIdx, TextCellValue(_dateFormat.format(v.expiresAt)),
          dataStyle);
      _setCell(
          sheet,
          8,
          rowIdx,
          TextCellValue(
              v.redeemedAt != null ? _dateFormat.format(v.redeemedAt!) : '—'),
          dataStyle);
      _setCell(sheet, 9, rowIdx, TextCellValue(v.voidReason ?? '—'), dataStyle);
    }

    _autoFitColumns(sheet, headers.length);

    final sanitizedLabel =
        filterLabel.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
    final defaultFileName =
        'vouchers_${sanitizedLabel}_${_fileTimestamp.format(DateTime.now())}.xlsx';
    return await _saveWorkbook(excel, defaultFileName);
  }

  /// Exports redeemed sales history and analytics to Excel.
  static Future<String?> exportSalesReport({
    required List<VoucherEntry> sales,
    required String dateFilterLabel,
    String? tierFilterLabel,
  }) async {
    if (sales.isEmpty) return null;

    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    final sheetName = 'Sales & Revenue';
    excel.rename(defaultSheet ?? 'Sheet1', sheetName);
    final sheet = excel[sheetName];

    final titleStyle = CellStyle(
      bold: true,
      fontSize: 14,
      fontColorHex: ExcelColor.fromHexString('#0F172A'),
    );
    final metaStyle = CellStyle(
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString('#475569'),
    );
    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#0F766E'), // Dark teal
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    final dataStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
    final numberStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );
    final totalRowStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#0F172A'),
      backgroundColorHex: ExcelColor.fromHexString('#E2E8F0'),
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );

    // ── Title & Summary Block ───────────────────────────────────────────────
    final totalRevenue =
        sales.fold<double>(0.0, (acc, item) => acc + item.priceSnapshot);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = TextCellValue('Pic-nPrint — Sales & Revenue Report')
      ..cellStyle = titleStyle;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
      ..value = TextCellValue(
          'Period: $dateFilterLabel • Tier Filter: ${tierFilterLabel ?? "All Tiers"} • Generated: ${_dateFormat.format(DateTime.now())}')
      ..cellStyle = metaStyle;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2))
      ..value = TextCellValue(
          'Total Transactions: ${sales.length} • Gross Revenue: PHP ${totalRevenue.toStringAsFixed(2)}')
      ..cellStyle = CellStyle(
          bold: true,
          fontSize: 11,
          fontColorHex: ExcelColor.fromHexString('#0F766E'));

    // ── Table Headers ───────────────────────────────────────────────────────
    final headers = [
      'Voucher Code',
      'Tier Mode',
      'Amount (PHP)',
      'Redeemed At',
      'Created Date',
      'Location ID',
    ];

    final tableStartRow = 4;
    for (var col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(
          columnIndex: col, rowIndex: tableStartRow));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = headerStyle;
    }

    // ── Rows ────────────────────────────────────────────────────────────────
    for (var r = 0; r < sales.length; r++) {
      final v = sales[r];
      final rowIdx = tableStartRow + 1 + r;
      final mode = ShotModeExtension.fromTierChar(v.tierChar);

      _setCell(sheet, 0, rowIdx, TextCellValue(v.code), dataStyle);
      _setCell(sheet, 1, rowIdx, TextCellValue(mode.label), dataStyle);
      _setCell(sheet, 2, rowIdx, DoubleCellValue(v.priceSnapshot), numberStyle);
      _setCell(
          sheet,
          3,
          rowIdx,
          TextCellValue(
              v.redeemedAt != null ? _dateFormat.format(v.redeemedAt!) : '—'),
          dataStyle);
      _setCell(sheet, 4, rowIdx, TextCellValue(_dateFormat.format(v.createdAt)),
          dataStyle);
      _setCell(sheet, 5, rowIdx, TextCellValue(v.locationId), dataStyle);
    }

    // ── Total Summary Row ───────────────────────────────────────────────────
    final totalRowIdx = tableStartRow + 1 + sales.length;
    _setCell(sheet, 0, totalRowIdx, TextCellValue('TOTAL'), totalRowStyle);
    _setCell(sheet, 1, totalRowIdx, TextCellValue('${sales.length} orders'),
        totalRowStyle);
    _setCell(
        sheet, 2, totalRowIdx, DoubleCellValue(totalRevenue), totalRowStyle);
    _setCell(sheet, 3, totalRowIdx, TextCellValue(''), totalRowStyle);
    _setCell(sheet, 4, totalRowIdx, TextCellValue(''), totalRowStyle);
    _setCell(sheet, 5, totalRowIdx, TextCellValue(''), totalRowStyle);

    _autoFitColumns(sheet, headers.length);

    final sanitizedPeriod =
        dateFilterLabel.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
    final defaultFileName =
        'sales_${sanitizedPeriod}_${_fileTimestamp.format(DateTime.now())}.xlsx';
    return await _saveWorkbook(excel, defaultFileName);
  }

  // ─── Private Helpers ────────────────────────────────────────────────────────

  static void _setCell(
      Sheet sheet, int col, int row, CellValue value, CellStyle style) {
    final cell =
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = value;
    cell.cellStyle = style;
  }

  static void _autoFitColumns(Sheet sheet, int columnCount) {
    for (var col = 0; col < columnCount; col++) {
      sheet.setColumnWidth(col, 22.0);
    }
  }

  static Future<String?> _saveWorkbook(
      Excel excel, String defaultFileName) async {
    final fileBytes = excel.save();
    if (fileBytes == null || fileBytes.isEmpty) {
      throw Exception('Failed to generate Excel file content.');
    }

    String? selectedPath;

    try {
      final saveLocation = await getSaveLocation(
        suggestedName: defaultFileName,
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Excel Spreadsheet',
            extensions: ['xlsx'],
          ),
        ],
      );
      if (saveLocation != null) {
        selectedPath = saveLocation.path;
      }
    } catch (_) {
      // Fallback if dialog is unavailable or fails
    }

    // If cancelled by the user in the file dialog
    if (selectedPath == null && Platform.isWindows) {
      // User explicitly cancelled the file picker dialog
      return null;
    }

    // If file_selector wasn't able to return a path, fallback to Downloads or Documents
    if (selectedPath == null) {
      final dir = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      selectedPath = p.join(dir.path, defaultFileName);
    }

    // Ensure extension ends with .xlsx
    if (!selectedPath.toLowerCase().endsWith('.xlsx')) {
      selectedPath = '$selectedPath.xlsx';
    }

    final file = File(selectedPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(fileBytes);
    return file.path;
  }

  /// Reveals the file in Windows Explorer (or macOS Finder).
  static Future<void> openInExplorer(String filePath) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', ['/select,', filePath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', filePath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [p.dirname(filePath)]);
      }
    } catch (_) {
      // Best-effort
    }
  }
}
