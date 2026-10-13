import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import 'package:barcode_widget/barcode_widget.dart';

import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import '../../../core/database/app_database.dart';
import '../../../core/models/models.dart';
import '../../../core/services/voucher_service.dart';
import '../../../core/services/printer_service.dart';
import '../../../core/services/security_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';

/// Admin panel — protected by bcrypt password gate.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminBloc, AdminState>(
      builder: (context, state) {
        if (state is AdminLockedState || state is AdminUnlocking) {
          return const _PasswordGate();
        }
        if (state is AdminPasswordWrong) {
          return _PasswordGate(
            error:
                'Wrong password. ${state.attemptsRemaining} attempts remaining.',
          );
        }
        if (state is AdminPasswordLocked) {
          return _LockoutScreen(remaining: state.remaining);
        }
        if (state is AdminUnlockedState) {
          return _AdminPanel(state: state);
        }
        return const SizedBox.shrink();
      },
    );
  }
}

// ─── Password Gate ────────────────────────────────────────────────────────────

class _PasswordGate extends StatefulWidget {
  final String? error;
  const _PasswordGate({this.error});

  @override
  State<_PasswordGate> createState() => _PasswordGateState();
}

class _PasswordGateState extends State<_PasswordGate> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Admin Access'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.goNamed(AppRoute.attract),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.admin_panel_settings_rounded,
                  size: 72,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Admin Panel',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter admin password to continue.\n(Default on fresh install is blank or "admin")',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _ctrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(
                      Icons.lock_rounded,
                      color: AppColors.onSurface,
                    ),
                    errorText: widget.error,
                  ),
                  onSubmitted: (_) => _submit(context),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: BlocBuilder<AdminBloc, AdminState>(
                    builder: (context, state) => ElevatedButton(
                      onPressed: state is AdminUnlocking
                          ? null
                          : () => _submit(context),
                      child: state is AdminUnlocking
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Unlock'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit(BuildContext context) {
    context.read<AdminBloc>().add(AdminPasswordSubmitted(_ctrl.text));
  }
}

// ─── Lockout Screen ───────────────────────────────────────────────────────────

class _LockoutScreen extends StatelessWidget {
  final Duration remaining;
  const _LockoutScreen({required this.remaining});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_rounded, size: 80, color: AppColors.error),
            const SizedBox(height: 24),
            Text(
              'Admin Panel Locked',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Try again in ${remaining.inMinutes} min ${remaining.inSeconds % 60} sec.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            TextButton(
              onPressed: () => context.goNamed(AppRoute.attract),
              child: const Text('Back to Start'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Admin Panel (unlocked) ───────────────────────────────────────────────────

class _AdminPanel extends StatelessWidget {
  final AdminUnlockedState state;
  const _AdminPanel({required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            label: const Text('Exit', style: TextStyle(color: AppColors.error)),
            onPressed: () {
              context.read<AdminBloc>().add(const AdminLocked());
              context.goNamed(AppRoute.attract);
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // ── Sidebar ─────────────────────────────────────────────────────────
          Container(
            width: 210,
            color: AppColors.surface,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: AdminSection.values.map((section) {
                final isActive = state.activeSection == section;
                return ListTile(
                  leading: Icon(
                    _iconFor(section),
                    color: isActive ? AppColors.primary : AppColors.onSurface,
                  ),
                  title: Text(
                    _labelFor(section),
                    style: TextStyle(
                      color: isActive
                          ? AppColors.primary
                          : AppColors.onBackground,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  selected: isActive,
                  selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
                  onTap: () => context.read<AdminBloc>().add(
                    AdminSectionChanged(section),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Section Content ──────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _SectionContent(
                section: state.activeSection,
                settings: state.settings,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(AdminSection s) {
    switch (s) {
      case AdminSection.pricing:
        return Icons.attach_money_rounded;
      case AdminSection.camera:
        return Icons.camera_alt_rounded;
      case AdminSection.printers:
        return Icons.print_rounded;
      case AdminSection.drive:
        return Icons.cloud_upload_rounded;
      case AdminSection.branding:
        return Icons.palette_rounded;
      case AdminSection.vouchers:
        return Icons.confirmation_number_rounded;
      case AdminSection.data:
        return Icons.security_rounded;
    }
  }

  String _labelFor(AdminSection s) {
    switch (s) {
      case AdminSection.pricing:
        return 'Pricing';
      case AdminSection.camera:
        return 'Camera';
      case AdminSection.printers:
        return 'Printers';
      case AdminSection.drive:
        return 'Drive';
      case AdminSection.branding:
        return 'Branding';
      case AdminSection.vouchers:
        return 'Vouchers & Sales';
      case AdminSection.data:
        return 'Data & Security';
    }
  }
}

// ─── Section Content Router ───────────────────────────────────────────────────

class _SectionContent extends StatelessWidget {
  final AdminSection section;
  final Map<String, String> settings;

  const _SectionContent({required this.section, required this.settings});

  @override
  Widget build(BuildContext context) {
    switch (section) {
      case AdminSection.pricing:
        return _PricingSection(settings: settings);
      case AdminSection.camera:
        return _CameraSection(settings: settings);
      case AdminSection.printers:
        return const _PrintersSection();
      case AdminSection.drive:
        return _DriveSection(settings: settings);
      case AdminSection.branding:
        return _BrandingSection(settings: settings);
      case AdminSection.vouchers:
        return _VouchersSection(settings: settings);
      case AdminSection.data:
        return _DataSection(settings: settings);
    }
  }
}

// ─── Setting Field Helper ─────────────────────────────────────────────────────

class _SettingField extends StatelessWidget {
  final String label;
  final String settingKey;
  final String currentValue;
  final String hint;

  const _SettingField({
    required this.label,
    required this.settingKey,
    required this.currentValue,
    this.hint = '',
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = TextEditingController(text: currentValue);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                decoration: InputDecoration(hintText: hint),
                onSubmitted: (v) {
                  context.read<AdminBloc>().add(
                    AdminSettingUpdated(key: settingKey, value: v),
                  );
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('$label updated')));
                },
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                context.read<AdminBloc>().add(
                  AdminSettingUpdated(key: settingKey, value: ctrl.text),
                );
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('$label saved')));
              },
              child: const Text('Save'),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ─── 1. Pricing Section ───────────────────────────────────────────────────────

class _PricingSection extends StatelessWidget {
  final Map<String, String> settings;
  const _PricingSection({required this.settings});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text(
          'Pricing Settings',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Set price in PHP per tier mode snapshot.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurface),
        ),
        const SizedBox(height: 24),
        _SettingField(
          label: 'Single Shot (1 photo) — PHP',
          settingKey: 'price_S',
          currentValue: settings['price_S'] ?? '50',
          hint: '50.00',
        ),
        _SettingField(
          label: '3 Shots (Triple) — PHP',
          settingKey: 'price_T',
          currentValue: settings['price_T'] ?? '80',
          hint: '80.00',
        ),
        _SettingField(
          label: '4 Shots (Quad) — PHP',
          settingKey: 'price_F',
          currentValue: settings['price_F'] ?? '100',
          hint: '100.00',
        ),
        _SettingField(
          label: '6 Shots (Hex) — PHP',
          settingKey: 'price_X',
          currentValue: settings['price_X'] ?? '120',
          hint: '120.00',
        ),
      ],
    );
  }
}

// ─── 2. Camera Section ────────────────────────────────────────────────────────

class _CameraSection extends StatelessWidget {
  final Map<String, String> settings;
  const _CameraSection({required this.settings});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text(
          'Camera & Countdown',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 24),
        _SettingField(
          label: 'Countdown seconds',
          settingKey: 'countdown_seconds',
          currentValue: settings['countdown_seconds'] ?? '3',
          hint: '3',
        ),
        _SettingField(
          label: 'Gap between shots (seconds)',
          settingKey: 'shot_gap_seconds',
          currentValue: settings['shot_gap_seconds'] ?? '2',
          hint: '2',
        ),
      ],
    );
  }
}

// ─── 3. Printers Section ──────────────────────────────────────────────────────

class _PrintersSection extends StatefulWidget {
  const _PrintersSection();

  @override
  State<_PrintersSection> createState() => _PrintersSectionState();
}

class _PrintersSectionState extends State<_PrintersSection> {
  late Future<List<PrinterEntry>> _printersFuture;

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  void _loadPrinters() {
    _printersFuture = context.read<AppDatabase>().getAllPrinters();
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    final printerService = context.read<PrinterService>();

    return ListView(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Printers',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Manage thermal receipt printers for vouchers & photo receipts.',
                  style: TextStyle(color: AppColors.onSurface),
                ),
              ],
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Printer'),
              onPressed: () => _showAddPrinterDialog(context),
            ),
          ],
        ),
        const SizedBox(height: 24),

        FutureBuilder<List<PrinterEntry>>(
          future: _printersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final printers = snapshot.data ?? [];
            if (printers.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.print_disabled_rounded,
                      size: 60,
                      color: AppColors.onSurface,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Printers Configured',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add a network (TCP/IP), USB, or Bluetooth thermal printer to enable receipts.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.onSurface),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Your First Printer'),
                      onPressed: () => _showAddPrinterDialog(context),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: printers.map((p) {
                final model = PrinterModel(
                  id: p.id,
                  name: p.name,
                  transport: _parseTransport(p.transport),
                  address: p.address,
                  paperWidthMm: p.paperWidthMm,
                  isDefault: p.isDefault,
                );

                return Card(
                  color: AppColors.surface,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: p.isDefault ? AppColors.primary : Colors.white12,
                      width: p.isDefault ? 2 : 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: p.isDefault
                                ? AppColors.primary.withValues(alpha: 0.2)
                                : Colors.white10,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.print_rounded,
                            color: p.isDefault
                                ? AppColors.primary
                                : Colors.white70,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    p.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (p.isDefault) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'DEFAULT',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Chip(
                                    label: Text(model.transport.label),
                                    backgroundColor: Colors.white10,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const SizedBox(width: 8),
                                  Chip(
                                    label: Text('${p.paperWidthMm}mm'),
                                    backgroundColor: Colors.white10,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Address: ${p.address}',
                                    style: const TextStyle(
                                      color: AppColors.onSurface,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Action buttons
                        OutlinedButton.icon(
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: const Text('Test Print'),
                          onPressed: () async {
                            try {
                              await printerService.testPrint(model);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Test print sent to ${p.name}!',
                                    ),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Print error: $e'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        if (!p.isDefault)
                          TextButton(
                            onPressed: () async {
                              await db.setDefaultPrinter(p.id);
                              setState(_loadPrinters);
                            },
                            child: const Text('Set Default'),
                          ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.error,
                          ),
                          tooltip: 'Delete Printer',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Printer'),
                                content: Text('Remove ${p.name}?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.error,
                                    ),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await db.deletePrinter(p.id);
                              setState(_loadPrinters);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  void _showAddPrinterDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final addrCtrl = TextEditingController(text: '192.168.1.100');
    var selectedTransport = PrinterTransport.network;
    var selectedPaperWidth = 80;
    var isDefault = true;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Add Printer'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Printer Name',
                    hintText: 'e.g. Receipt Printer 1',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<PrinterTransport>(
                  value: selectedTransport,
                  decoration: const InputDecoration(
                    labelText: 'Connection Type',
                  ),
                  items: PrinterTransport.values
                      .map(
                        (t) => DropdownMenuItem(value: t, child: Text(t.label)),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() {
                        selectedTransport = v;
                        if (v == PrinterTransport.network) {
                          addrCtrl.text = '192.168.1.100';
                        } else if (v == PrinterTransport.usb) {
                          addrCtrl.text = 'COM3';
                        } else {
                          addrCtrl.text = '00:11:22:33:44:55';
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: addrCtrl,
                  decoration: InputDecoration(
                    labelText: selectedTransport == PrinterTransport.network
                        ? 'IP Address (Port 9100)'
                        : selectedTransport == PrinterTransport.usb
                        ? 'Port / Device Path'
                        : 'Bluetooth MAC Address',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedPaperWidth,
                  decoration: const InputDecoration(labelText: 'Paper Width'),
                  items: const [
                    DropdownMenuItem(
                      value: 80,
                      child: Text('80mm (Standard receipt)'),
                    ),
                    DropdownMenuItem(
                      value: 58,
                      child: Text('58mm (Compact receipt)'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedPaperWidth = v);
                  },
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Set as Default Printer'),
                  value: isDefault,
                  onChanged: (v) =>
                      setDialogState(() => isDefault = v ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final addr = addrCtrl.text.trim();
                if (name.isEmpty || addr.isEmpty) return;

                final id = const Uuid().v4();
                final db = context.read<AppDatabase>();
                await db.upsertPrinter(
                  PrintersTableCompanion(
                    id: drift.Value(id),
                    name: drift.Value(name),
                    transport: drift.Value(selectedTransport.name),
                    address: drift.Value(addr),
                    paperWidthMm: drift.Value(selectedPaperWidth),
                    isDefault: drift.Value(isDefault),
                  ),
                );

                if (isDefault) {
                  await db.setDefaultPrinter(id);
                }

                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                setState(_loadPrinters);
              },
              child: const Text('Save Printer'),
            ),
          ],
        ),
      ),
    );
  }

  PrinterTransport _parseTransport(String str) {
    switch (str.toLowerCase()) {
      case 'usb':
        return PrinterTransport.usb;
      case 'bluetooth':
        return PrinterTransport.bluetooth;
      default:
        return PrinterTransport.network;
    }
  }
}

// ─── 4. Drive Section ─────────────────────────────────────────────────────────

class _DriveSection extends StatelessWidget {
  final Map<String, String> settings;
  const _DriveSection({required this.settings});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text('Google Drive', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'Configure Google Drive cloud upload for high-res photo sharing via QR.',
          style: TextStyle(color: AppColors.onSurface),
        ),
        const SizedBox(height: 24),
        _SettingField(
          label: 'Drive Folder ID',
          settingKey: 'drive_folder_id',
          currentValue: settings['drive_folder_id'] ?? '',
          hint: 'e.g. 1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs',
        ),
        Text(
          'Service Account JSON',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 6),
        TextFormField(
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: '{ "type": "service_account", ... }',
          ),
          initialValue: settings['drive_service_account_json'] ?? '',
          onChanged: (v) => context.read<AdminBloc>().add(
            AdminSettingUpdated(key: 'drive_service_account_json', value: v),
          ),
        ),
      ],
    );
  }
}

// ─── 5. Branding Section ──────────────────────────────────────────────────────

class _BrandingSection extends StatelessWidget {
  final Map<String, String> settings;
  const _BrandingSection({required this.settings});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text(
          'Branding & Text',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Customize kiosk name, subtitles, and thermal receipt headers.',
          style: TextStyle(color: AppColors.onSurface),
        ),
        const SizedBox(height: 24),
        _SettingField(
          label: 'Kiosk App Title',
          settingKey: 'kiosk_title',
          currentValue: settings['kiosk_title'] ?? 'PhotoReceipt',
          hint: 'PhotoReceipt',
        ),
        _SettingField(
          label: 'Kiosk Subtitle',
          settingKey: 'kiosk_subtitle',
          currentValue:
              settings['kiosk_subtitle'] ?? 'Your memories, printed instantly.',
          hint: 'Your memories, printed instantly.',
        ),
        _SettingField(
          label: 'Receipt Header Note',
          settingKey: 'receipt_header',
          currentValue: settings['receipt_header'] ?? 'THANK YOU FOR VISITING!',
          hint: 'THANK YOU FOR VISITING!',
        ),
        _SettingField(
          label: 'Receipt Footer Note',
          settingKey: 'receipt_footer',
          currentValue: settings['receipt_footer'] ?? 'Visit us again soon!',
          hint: 'Visit us again soon!',
        ),
      ],
    );
  }
}

// ─── 6. Vouchers & Cashier Section ────────────────────────────────────────────

class _VouchersSection extends StatefulWidget {
  final Map<String, String> settings;
  const _VouchersSection({required this.settings});

  @override
  State<_VouchersSection> createState() => _VouchersSectionState();
}

class _VouchersSectionState extends State<_VouchersSection> {
  ShotMode _selectedMode = ShotMode.quad;
  VoucherModel? _lastGeneratedVoucher;
  bool _isGenerating = false;
  late Future<List<VoucherEntry>> _vouchersFuture;

  @override
  void initState() {
    super.initState();
    _loadVouchers();
  }

  void _loadVouchers() {
    _vouchersFuture = context.read<AppDatabase>().getAllVouchers();
  }

  @override
  Widget build(BuildContext context) {
    final voucherService = context.read<VoucherService>();
    final db = context.read<AppDatabase>();

    return ListView(
      children: [
        Text(
          'Vouchers & Cashier Hub',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Generate customer voucher tickets, print slips, and manage sales history.',
          style: TextStyle(color: AppColors.onSurface),
        ),
        const SizedBox(height: 24),

        // ── Cashier Generator Card ───────────────────────────────────────────
        Card(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Generate Customer Voucher',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select Shot Mode / Tier:',
                  style: TextStyle(color: AppColors.onSurface),
                ),
                const SizedBox(height: 12),

                // Tier selection chips
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: ShotMode.values.map((mode) {
                    final isSelected = _selectedMode == mode;
                    final priceKey = 'price_${mode.tierChar}';
                    final price =
                        widget.settings[priceKey] ??
                        (mode == ShotMode.single
                            ? '50'
                            : mode == ShotMode.triple
                            ? '80'
                            : mode == ShotMode.quad
                            ? '100'
                            : '120');

                    return ChoiceChip(
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      label: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Column(
                          children: [
                            Text(
                              mode.label,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.onBackground,
                              ),
                            ),
                            Text(
                              '₱$price • ${mode.photoCount} photo${mode.photoCount > 1 ? "s" : ""}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected
                                    ? Colors.white70
                                    : AppColors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      onSelected: (_) => setState(() => _selectedMode = mode),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.confirmation_number_rounded),
                    label: Text(
                      _isGenerating
                          ? 'Generating Voucher…'
                          : 'Generate & Print Voucher (₱${widget.settings['price_${_selectedMode.tierChar}'] ?? "100"})',
                    ),
                    onPressed: _isGenerating
                        ? null
                        : () async {
                            setState(() => _isGenerating = true);
                            try {
                              final voucher = await voucherService
                                  .generateVoucher(mode: _selectedMode);

                              // Try printing voucher ticket if default printer exists
                              try {
                                final printers = await db.getAllPrinters();
                                final defaultPrinter = printers
                                    .where((p) => p.isDefault)
                                    .firstOrNull;
                                if (defaultPrinter != null && context.mounted) {
                                  final printerModel = PrinterModel(
                                    id: defaultPrinter.id,
                                    name: defaultPrinter.name,
                                    transport: defaultPrinter.transport == 'usb'
                                        ? PrinterTransport.usb
                                        : defaultPrinter.transport ==
                                              'bluetooth'
                                        ? PrinterTransport.bluetooth
                                        : PrinterTransport.network,
                                    address: defaultPrinter.address,
                                    paperWidthMm: defaultPrinter.paperWidthMm,
                                    isDefault: true,
                                  );
                                  await context.read<PrinterService>().printText(
                                    printer: printerModel,
                                    text:
                                        '================================\n'
                                        '       PHOTORECEIPT VOUCHER     \n'
                                        '================================\n'
                                        'CODE: ${voucher.code}\n'
                                        'TIER: ${_selectedMode.label} (${_selectedMode.photoCount} Photos)\n'
                                        'PRICE: ₱${voucher.priceSnapshot}\n'
                                        'EXPIRES: ${voucher.expiresAt.toString().substring(0, 16)}\n'
                                        '================================\n'
                                        'Type this code at the kiosk!\n\n',
                                  );
                                }
                              } catch (_) {}

                              setState(() {
                                _lastGeneratedVoucher = voucher;
                                _loadVouchers();
                              });

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Generated voucher: ${voucher.code}',
                                    ),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            } finally {
                              setState(() => _isGenerating = false);
                            }
                          },
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Highlight Last Generated Voucher ──────────────────────────────────
        if (_lastGeneratedVoucher != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CUSTOMER VOUCHER READY',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        _lastGeneratedVoucher!.code,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_lastGeneratedVoucher!.shotMode.label} • ₱${_lastGeneratedVoucher!.priceSnapshot.toStringAsFixed(2)} • Expires in 24 hrs',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 140,
                  height: 60,
                  child: BarcodeWidget(
                    barcode: Barcode.code128(),
                    data: _lastGeneratedVoucher!.code,
                    color: Colors.white,
                    drawText: false,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy Code'),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: _lastGeneratedVoucher!.code),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Voucher code copied to clipboard!'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 32),

        // ── Recent Vouchers Table ─────────────────────────────────────────────
        Text(
          'Voucher Sales History',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),

        FutureBuilder<List<VoucherEntry>>(
          future: _vouchersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final vouchers = (snapshot.data ?? []).reversed.toList();
            if (vouchers.isEmpty) {
              return const Card(
                color: AppColors.surface,
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No vouchers generated yet.')),
                ),
              );
            }

            return Card(
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Code')),
                    DataColumn(label: Text('Tier')),
                    DataColumn(label: Text('Price')),
                    DataColumn(label: Text('Created')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: vouchers.take(25).map((v) {
                    final isUsed = v.status == 'used';
                    final isActive = v.status == 'active';

                    return DataRow(
                      cells: [
                        DataCell(
                          SelectableText(
                            v.code,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataCell(Text(v.tierChar)),
                        DataCell(
                          Text('₱${v.priceSnapshot.toStringAsFixed(2)}'),
                        ),
                        DataCell(Text(v.createdAt.toString().substring(0, 16))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.success.withValues(alpha: 0.2)
                                  : isUsed
                                  ? Colors.white10
                                  : AppColors.error.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              v.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isActive
                                    ? AppColors.success
                                    : isUsed
                                    ? Colors.white70
                                    : AppColors.error,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          isActive
                              ? TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                  ),
                                  onPressed: () async {
                                    await db.updateVoucherStatus(
                                      v.code,
                                      'voided',
                                      voidReason: 'Cashier void',
                                    );
                                    setState(_loadVouchers);
                                  },
                                  child: const Text('Void'),
                                )
                              : const Text('—'),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─── 7. Data & Security Section ───────────────────────────────────────────────

class _DataSection extends StatefulWidget {
  final Map<String, String> settings;
  const _DataSection({required this.settings});

  @override
  State<_DataSection> createState() => _DataSectionState();
}

class _DataSectionState extends State<_DataSection> {
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  bool _obscure = true;
  bool _isUpdatingPw = false;

  @override
  void dispose() {
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final securityService = context.read<SecurityService>();
    final storageService = context.read<StorageService>();

    return ListView(
      children: [
        Text(
          'Security & System Data',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Update admin credentials, kiosk location parameters, and run maintenance cleanup.',
          style: TextStyle(color: AppColors.onSurface),
        ),
        const SizedBox(height: 24),

        // ── Admin Password Card ──────────────────────────────────────────────
        Card(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.lock_reset_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Change Admin Password',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _newPwCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: const Icon(Icons.key_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPwCtrl,
                  obscureText: _obscure,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: const Icon(Icons.check_circle_outline_rounded),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isUpdatingPw
                      ? null
                      : () async {
                          final newPw = _newPwCtrl.text.trim();
                          final confirmPw = _confirmPwCtrl.text.trim();

                          if (newPw.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Password cannot be empty.'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }
                          if (newPw != confirmPw) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Passwords do not match.'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }

                          setState(() => _isUpdatingPw = true);
                          try {
                            await securityService.setPassword(newPw);
                            _newPwCtrl.clear();
                            _confirmPwCtrl.clear();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Admin password successfully updated!',
                                  ),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to update password: $e',
                                  ),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          } finally {
                            setState(() => _isUpdatingPw = false);
                          }
                        },
                  child: Text(
                    _isUpdatingPw ? 'Updating…' : 'Update Admin Password',
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ── Location & Voucher Secret Card ────────────────────────────────────
        Card(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.location_pin,
                      color: AppColors.primary,
                      size: 28,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Location & Voucher HMAC Secret',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _SettingField(
                  label: 'Kiosk Location ID',
                  settingKey: 'location_id',
                  currentValue: widget.settings['location_id'] ?? 'MNL1',
                  hint: 'e.g. MNL1',
                ),
                _SettingField(
                  label: 'Voucher Cryptographic Secret Key',
                  settingKey: 'voucher_secret',
                  currentValue: widget.settings['voucher_secret'] ?? '',
                  hint: 'Secret HMAC key used for checksum verification',
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.shuffle_rounded),
                  label: const Text('Generate New Random Secret'),
                  onPressed: () {
                    final rand = Random.secure();
                    final bytes = List<int>.generate(
                      16,
                      (_) => rand.nextInt(256),
                    );
                    final hex = bytes
                        .map((b) => b.toRadixString(16).padLeft(2, '0'))
                        .join();
                    context.read<AdminBloc>().add(
                      AdminSettingUpdated(key: 'voucher_secret', value: hex),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'New voucher secret generated and saved!',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ── Storage Cleanup Card ──────────────────────────────────────────────
        Card(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.cleaning_services_rounded,
                      color: AppColors.warning,
                      size: 28,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Local Storage Maintenance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'The kiosk automatically purges local raw images and composed receipts older than 7 days on startup. You can also trigger the cleanup immediately.',
                  style: TextStyle(color: AppColors.onSurface),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete_sweep_rounded),
                  label: const Text('Run 7-Day Disk Cleanup Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                  ),
                  onPressed: () async {
                    try {
                      await storageService.runCleanup();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cleanup completed successfully!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Cleanup failed: $e'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
