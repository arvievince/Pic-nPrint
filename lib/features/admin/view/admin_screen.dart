import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import '../../../core/database/app_database.dart';
import '../../../core/models/models.dart';
import '../../../core/services/voucher_service.dart';
import '../../../core/services/pricing_service.dart';
import '../../../core/services/printer_service.dart';
import '../../../core/services/security_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/excel_export_service.dart';
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

class _AdminPanel extends StatefulWidget {
  final AdminUnlockedState state;
  const _AdminPanel({required this.state});

  @override
  State<_AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<_AdminPanel> {
  static const double _kBreakpoint = 800.0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSidebarExpanded = true;

  void _selectSection(BuildContext context, AdminSection section,
      {required bool isCompact}) {
    context.read<AdminBloc>().add(AdminSectionChanged(section));
    if (isCompact) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < _kBreakpoint;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            isCompact
                ? Icons.menu_rounded
                : (_isSidebarExpanded
                    ? Icons.menu_open_rounded
                    : Icons.menu_rounded),
          ),
          tooltip: isCompact
              ? 'Open menu'
              : (_isSidebarExpanded ? 'Collapse sidebar' : 'Expand sidebar'),
          onPressed: () {
            if (isCompact) {
              _scaffoldKey.currentState?.openDrawer();
            } else {
              setState(() => _isSidebarExpanded = !_isSidebarExpanded);
            }
          },
        ),
        title: Text('Admin Panel • ${_labelFor(widget.state.activeSection)}'),
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
      drawer: isCompact
          ? _AdminSidebar(
              state: widget.state,
              isDrawer: true,
              onSelectSection: (section) =>
                  _selectSection(context, section, isCompact: true),
            )
          : null,
      body: Row(
        children: [
          // ── Persistent Sidebar on Wide Screens ────────────────────────────
          if (!isCompact && _isSidebarExpanded)
            _AdminSidebar(
              state: widget.state,
              isDrawer: false,
              onSelectSection: (section) =>
                  _selectSection(context, section, isCompact: false),
            ),

          // ── Section Content ──────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(isCompact ? 16 : 24),
              child: _SectionContent(
                section: widget.state.activeSection,
                settings: widget.state.settings,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Admin Sidebar ────────────────────────────────────────────────────────────

class _AdminSidebar extends StatelessWidget {
  final AdminUnlockedState state;
  final ValueChanged<AdminSection> onSelectSection;
  final bool isDrawer;

  const _AdminSidebar({
    required this.state,
    required this.onSelectSection,
    this.isDrawer = false,
  });

  @override
  Widget build(BuildContext context) {
    final listContent = ListView(
      padding: EdgeInsets.symmetric(vertical: isDrawer ? 0 : 8),
      children: [
        if (isDrawer)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 44, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.5),
              border: const Border(
                bottom: BorderSide(color: Colors.white10),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pic-nPrint',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.onBackground,
                        ),
                      ),
                      Text(
                        'Admin Settings',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ...AdminSection.values.map((section) {
          final isActive = state.activeSection == section;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: ListTile(
              leading: Icon(
                _iconFor(section),
                color: isActive ? AppColors.primary : AppColors.onSurface,
              ),
              title: Text(
                _labelFor(section),
                style: TextStyle(
                  color: isActive ? AppColors.primary : AppColors.onBackground,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
              selected: isActive,
              selectedTileColor: AppColors.primary.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              onTap: () => onSelectSection(section),
            ),
          );
        }),
      ],
    );

    if (isDrawer) {
      return Drawer(
        backgroundColor: AppColors.surface,
        child: SafeArea(
          top: false,
          child: listContent,
        ),
      );
    }

    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(color: Colors.white10),
        ),
      ),
      child: listContent,
    );
  }
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
    case AdminSection.sales:
      return Icons.point_of_sale_rounded;
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
      return 'Vouchers';
    case AdminSection.sales:
      return 'Sales & Revenue';
    case AdminSection.data:
      return 'Data & Security';
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
      case AdminSection.sales:
        return _SalesSection(settings: settings);
      case AdminSection.data:
        return _DataSection(settings: settings);
    }
  }
}

// ─── 1. Pricing Section ───────────────────────────────────────────────────────

class _PricingSection extends StatefulWidget {
  final Map<String, String> settings;
  const _PricingSection({required this.settings});

  @override
  State<_PricingSection> createState() => _PricingSectionState();
}

class _PricingSectionState extends State<_PricingSection> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _singleCtrl;
  late final TextEditingController _tripleCtrl;
  late final TextEditingController _quadCtrl;
  late final TextEditingController _hexCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _singleCtrl = TextEditingController(
      text: widget.settings['price_S'] ??
          PricingService.defaultPrices[ShotMode.single]!.toStringAsFixed(2),
    );
    _tripleCtrl = TextEditingController(
      text: widget.settings['price_T'] ??
          PricingService.defaultPrices[ShotMode.triple]!.toStringAsFixed(2),
    );
    _quadCtrl = TextEditingController(
      text: widget.settings['price_F'] ??
          PricingService.defaultPrices[ShotMode.quad]!.toStringAsFixed(2),
    );
    _hexCtrl = TextEditingController(
      text: widget.settings['price_X'] ??
          PricingService.defaultPrices[ShotMode.hex]!.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _singleCtrl.dispose();
    _tripleCtrl.dispose();
    _quadCtrl.dispose();
    _hexCtrl.dispose();
    super.dispose();
  }

  Future<void> _savePrices() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final single = double.tryParse(_singleCtrl.text.trim());
    final triple = double.tryParse(_tripleCtrl.text.trim());
    final quad = double.tryParse(_quadCtrl.text.trim());
    final hex = double.tryParse(_hexCtrl.text.trim());

    if (single == null || triple == null || quad == null || hex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid numeric prices for all tiers.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final pricingMap = {
        ShotMode.single: single,
        ShotMode.triple: triple,
        ShotMode.quad: quad,
        ShotMode.hex: hex,
      };

      final pricingService = context.read<PricingService>();
      await pricingService.saveAllPrices(pricingMap);

      if (mounted) {
        context.read<AdminBloc>().add(AdminPricesUpdated(pricingMap));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pricing settings saved successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save prices: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildPriceInput({
    required String label,
    required String subtitle,
    required TextEditingController controller,
    required String hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(color: AppColors.onSurface, fontSize: 13)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              prefixText: '₱ ',
              prefixStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                fontSize: 16,
              ),
              hintText: hint,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            validator: (value) {
              final v = value?.trim() ?? '';
              if (v.isEmpty) {
                return 'Please enter a price';
              }
              final parsed = double.tryParse(v);
              if (parsed == null || parsed < 0) {
                return 'Please enter a valid non-negative amount';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          Text(
            'Pricing Settings',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Set price in PHP per tier mode snapshot. Changes will apply to voucher generation and receipts.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurface),
          ),
          const SizedBox(height: 24),
          _buildPriceInput(
            label: 'Single Shot (1 Photo)',
            subtitle: 'Quick single portrait snapshot',
            controller: _singleCtrl,
            hint: '50.00',
          ),
          _buildPriceInput(
            label: '3 Shots (Triple)',
            subtitle: '3-photo strip or mini grid layout',
            controller: _tripleCtrl,
            hint: '80.00',
          ),
          _buildPriceInput(
            label: '4 Shots (Quad)',
            subtitle: 'Classic 4-photo booth strip layout',
            controller: _quadCtrl,
            hint: '100.00',
          ),
          _buildPriceInput(
            label: '6 Shots (Hex)',
            subtitle: '6-photo double strip or extended layout',
            controller: _hexCtrl,
            hint: '120.00',
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_isSaving ? 'Saving...' : 'Save Pricing'),
              onPressed: _isSaving ? null : _savePrices,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── 2. Camera Section ────────────────────────────────────────────────────────

class _CameraSection extends StatefulWidget {
  final Map<String, String> settings;
  const _CameraSection({required this.settings});

  @override
  State<_CameraSection> createState() => _CameraSectionState();
}

class _CameraSectionState extends State<_CameraSection> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _countdownCtrl;
  late final TextEditingController _gapCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _countdownCtrl = TextEditingController(
      text: widget.settings['countdown_seconds'] ?? '3',
    );
    _gapCtrl = TextEditingController(
      text: widget.settings['shot_gap_seconds'] ?? '2',
    );
  }

  @override
  void dispose() {
    _countdownCtrl.dispose();
    _gapCtrl.dispose();
    super.dispose();
  }

  void _saveCameraSettings() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSaving = true);
    final countdown = _countdownCtrl.text.trim();
    final gap = _gapCtrl.text.trim();

    context.read<AdminBloc>().add(
          AdminMultipleSettingsUpdated({
            'countdown_seconds': countdown,
            'shot_gap_seconds': gap,
          }),
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Camera settings saved successfully!'),
        backgroundColor: AppColors.success,
      ),
    );

    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          Text(
            'Camera & Countdown',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Configure countdown timer and delay interval between burst snapshots.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurface),
          ),
          const SizedBox(height: 24),
          Text('Countdown Duration (seconds)',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          TextFormField(
            controller: _countdownCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              hintText: '3',
              suffixText: 'sec',
            ),
            validator: (v) {
              final val = int.tryParse(v?.trim() ?? '');
              if (val == null || val < 1) {
                return 'Please enter at least 1 second';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          Text('Gap Between Shots (seconds)',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          TextFormField(
            controller: _gapCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              hintText: '2',
              suffixText: 'sec',
            ),
            validator: (v) {
              final val = int.tryParse(v?.trim() ?? '');
              if (val == null || val < 1) {
                return 'Please enter at least 1 second';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_isSaving ? 'Saving...' : 'Save Camera Settings'),
              onPressed: _isSaving ? null : _saveCameraSettings,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
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
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 500;
            if (isNarrow) {
              return Column(
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
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Printer'),
                    onPressed: () => _showAddPrinterDialog(context),
                  ),
                ],
              );
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
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
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Printer'),
                  onPressed: () => _showAddPrinterDialog(context),
                ),
              ],
            );
          },
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

                return LayoutBuilder(
                  builder: (context, cardConstraints) {
                    final isCompactCard = cardConstraints.maxWidth < 620;

                    if (isCompactCard) {
                      return Card(
                        color: AppColors.surface,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: p.isDefault
                                ? AppColors.primary
                                : Colors.white12,
                            width: p.isDefault ? 2 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top header: Icon, Name + Badge, Delete button
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: p.isDefault
                                          ? AppColors.primary
                                              .withValues(alpha: 0.2)
                                          : Colors.white10,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.print_rounded,
                                      color: p.isDefault
                                          ? AppColors.primary
                                          : Colors.white70,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          p.name,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (p.isDefault)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'DEFAULT',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: AppColors.error,
                                      size: 22,
                                    ),
                                    tooltip: 'Delete Printer',
                                    onPressed: () =>
                                        _confirmDeletePrinter(context, db, p),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Chips and address with Wrap
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Chip(
                                    label: Text(model.transport.label),
                                    backgroundColor: Colors.white10,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  Chip(
                                    label: Text('${p.paperWidthMm}mm'),
                                    backgroundColor: Colors.white10,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  Text(
                                    'Address: ${p.address}',
                                    style: const TextStyle(
                                      color: AppColors.onSurface,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1, color: Colors.white10),
                              const SizedBox(height: 10),
                              // Action Buttons row
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.play_arrow_rounded,
                                        size: 18),
                                    label: const Text('Test Print'),
                                    onPressed: () => _testPrint(
                                        context, printerService, model, p.name),
                                  ),
                                  if (!p.isDefault)
                                    TextButton(
                                      onPressed: () async {
                                        await db.setDefaultPrinter(p.id);
                                        setState(_loadPrinters);
                                      },
                                      child: const Text('Set as Default'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Wide screen Card layout
                    return Card(
                      color: AppColors.surface,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color:
                              p.isDefault ? AppColors.primary : Colors.white12,
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
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        p.name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (p.isDefault)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius:
                                                BorderRadius.circular(8),
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
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Chip(
                                        label: Text(model.transport.label),
                                        backgroundColor: Colors.white10,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      Chip(
                                        label: Text('${p.paperWidthMm}mm'),
                                        backgroundColor: Colors.white10,
                                        visualDensity: VisualDensity.compact,
                                      ),
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
                            const SizedBox(width: 16),
                            // Action buttons
                            OutlinedButton.icon(
                              icon: const Icon(Icons.play_arrow_rounded,
                                  size: 18),
                              label: const Text('Test Print'),
                              onPressed: () => _testPrint(
                                  context, printerService, model, p.name),
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
                              onPressed: () =>
                                  _confirmDeletePrinter(context, db, p),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Future<void> _testPrint(
    BuildContext context,
    PrinterService printerService,
    PrinterModel model,
    String printerName,
  ) async {
    try {
      await printerService.testPrint(model);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test print sent to $printerName!'),
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
  }

  Future<void> _confirmDeletePrinter(
    BuildContext context,
    AppDatabase db,
    PrinterEntry p,
  ) async {
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
                  initialValue: selectedTransport,
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
                  initialValue: selectedPaperWidth,
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

class _DriveSection extends StatefulWidget {
  final Map<String, String> settings;
  const _DriveSection({required this.settings});

  @override
  State<_DriveSection> createState() => _DriveSectionState();
}

class _DriveSectionState extends State<_DriveSection> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _folderIdCtrl;
  late final TextEditingController _serviceAccountCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _folderIdCtrl = TextEditingController(
      text: widget.settings['drive_folder_id'] ?? '',
    );
    _serviceAccountCtrl = TextEditingController(
      text: widget.settings['drive_service_account_json'] ?? '',
    );
  }

  @override
  void dispose() {
    _folderIdCtrl.dispose();
    _serviceAccountCtrl.dispose();
    super.dispose();
  }

  void _saveDriveSettings() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSaving = true);
    final folderId = _folderIdCtrl.text.trim();
    final serviceAccountJson = _serviceAccountCtrl.text.trim();

    context.read<AdminBloc>().add(
          AdminMultipleSettingsUpdated({
            'drive_folder_id': folderId,
            'drive_service_account_json': serviceAccountJson,
          }),
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Google Drive settings saved successfully!'),
        backgroundColor: AppColors.success,
      ),
    );

    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          Text('Google Drive',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text(
            'Configure Google Drive cloud upload for high-res photo sharing via QR.',
            style: TextStyle(color: AppColors.onSurface),
          ),
          const SizedBox(height: 24),
          Text('Drive Folder ID',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          TextFormField(
            controller: _folderIdCtrl,
            decoration: const InputDecoration(
              hintText: 'e.g. 1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs',
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Service Account JSON',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _serviceAccountCtrl,
            maxLines: 8,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              hintText: '{ "type": "service_account", ... }',
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_isSaving ? 'Saving...' : 'Save Drive Settings'),
              onPressed: _isSaving ? null : _saveDriveSettings,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── 5. Branding Section ──────────────────────────────────────────────────────

class _BrandingSection extends StatefulWidget {
  final Map<String, String> settings;
  const _BrandingSection({required this.settings});

  @override
  State<_BrandingSection> createState() => _BrandingSectionState();
}

class _BrandingSectionState extends State<_BrandingSection> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _subtitleCtrl;
  late final TextEditingController _headerCtrl;
  late final TextEditingController _footerCtrl;
  bool _isSaving = false;
  bool _isUploadingLogo = false;
  String? _logoPath;

  @override
  void initState() {
    super.initState();
    _logoPath = widget.settings['kiosk_logo_path'];
    if (_logoPath != null &&
        (_logoPath!.trim().isEmpty || !File(_logoPath!.trim()).existsSync())) {
      _logoPath = null;
    }
    _titleCtrl = TextEditingController(
      text: widget.settings['kiosk_title'] ?? 'Pic & Print',
    );
    _subtitleCtrl = TextEditingController(
      text: widget.settings['kiosk_subtitle'] ??
          'Your memories, printed instantly.',
    );
    _headerCtrl = TextEditingController(
      text: widget.settings['receipt_header'] ?? 'THANK YOU FOR VISITING!',
    );
    _footerCtrl = TextEditingController(
      text: widget.settings['receipt_footer'] ?? 'Visit us again soon!',
    );
  }

  Future<void> _pickAndUploadLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _isUploadingLogo = true);
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final brandingDir = Directory(p.join(appDir.path, 'branding'));
      if (!brandingDir.existsSync()) {
        brandingDir.createSync(recursive: true);
      }
      final ext = p.extension(picked.path).isNotEmpty
          ? p.extension(picked.path)
          : '.png';
      final destPath = p.join(brandingDir.path, 'kiosk_logo$ext');
      await File(picked.path).copy(destPath);

      if (mounted) {
        context.read<AdminBloc>().add(
              AdminSettingUpdated(key: 'kiosk_logo_path', value: destPath),
            );
        setState(() {
          _logoPath = destPath;
          _isUploadingLogo = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo uploaded and saved successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingLogo = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save logo: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _removeLogo() {
    try {
      if (_logoPath != null && _logoPath!.isNotEmpty) {
        final f = File(_logoPath!);
        if (f.existsSync()) {
          f.deleteSync();
        }
      }
    } catch (_) {}

    context.read<AdminBloc>().add(
          const AdminSettingUpdated(key: 'kiosk_logo_path', value: ''),
        );
    setState(() => _logoPath = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Logo removed. Default camera icon will be used on attract screen.'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _headerCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  void _saveBrandingSettings() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSaving = true);

    context.read<AdminBloc>().add(
          AdminMultipleSettingsUpdated({
            'kiosk_title': _titleCtrl.text.trim(),
            'kiosk_subtitle': _subtitleCtrl.text.trim(),
            'receipt_header': _headerCtrl.text.trim(),
            'receipt_footer': _footerCtrl.text.trim(),
          }),
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Branding settings saved successfully!'),
        backgroundColor: AppColors.success,
      ),
    );

    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          Text(
            'Branding & Text',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Customize kiosk name, subtitles, logo, and thermal receipt headers.',
            style: TextStyle(color: AppColors.onSurface),
          ),
          const SizedBox(height: 24),
          // ── Kiosk Logo Card ──────────────────────────────────────────────────
          Card(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: AppColors.onSurface.withValues(alpha: 0.12),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.photo_library_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Kiosk Logo',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (_logoPath != null &&
                                  File(_logoPath!).existsSync())
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : AppColors.onSurface.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (_logoPath != null &&
                                    File(_logoPath!).existsSync())
                                ? AppColors.primary.withValues(alpha: 0.3)
                                : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          (_logoPath != null && File(_logoPath!).existsSync())
                              ? 'Custom Logo Active'
                              : 'Default Icon Active',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: (_logoPath != null &&
                                    File(_logoPath!).existsSync())
                                ? AppColors.primary
                                : AppColors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This logo will be displayed on the idle/attract welcome screen. If no custom logo is uploaded, the default camera icon is shown.',
                    style: TextStyle(color: AppColors.onSurface, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Preview Container matching attract screen aesthetic
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: (_logoPath != null &&
                                File(_logoPath!).existsSync())
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Image.file(
                                    File(_logoPath!),
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 50,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt_rounded,
                                size: 50,
                                color: AppColors.primary,
                              ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 10,
                              children: [
                                ElevatedButton.icon(
                                  icon: _isUploadingLogo
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.upload_file_rounded),
                                  label: Text(
                                    (_logoPath != null &&
                                            File(_logoPath!).existsSync())
                                        ? 'Change Logo'
                                        : 'Upload Logo',
                                  ),
                                  onPressed: _isUploadingLogo
                                      ? null
                                      : _pickAndUploadLogo,
                                ),
                                if (_logoPath != null &&
                                    File(_logoPath!).existsSync())
                                  OutlinedButton.icon(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: AppColors.error,
                                    ),
                                    label: const Text(
                                      'Remove Logo',
                                      style: TextStyle(color: AppColors.error),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: AppColors.error,
                                      ),
                                    ),
                                    onPressed:
                                        _isUploadingLogo ? null : _removeLogo,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Supports PNG, JPG, or WEBP. Square transparent PNG recommended for best visual appeal.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text('Kiosk App Title',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          TextFormField(
            controller: _titleCtrl,
            decoration: const InputDecoration(hintText: 'Pic & Print'),
          ),
          const SizedBox(height: 20),
          Text('Kiosk Subtitle', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          TextFormField(
            controller: _subtitleCtrl,
            decoration: const InputDecoration(
                hintText: 'Your memories, printed instantly.'),
          ),
          const SizedBox(height: 20),
          Text('Receipt Header Note',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          TextFormField(
            controller: _headerCtrl,
            decoration:
                const InputDecoration(hintText: 'THANK YOU FOR VISITING!'),
          ),
          const SizedBox(height: 20),
          Text('Receipt Footer Note',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          TextFormField(
            controller: _footerCtrl,
            decoration: const InputDecoration(hintText: 'Visit us again soon!'),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_isSaving ? 'Saving...' : 'Save Branding Settings'),
              onPressed: _isSaving ? null : _saveBrandingSettings,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── 6. Vouchers Section ──────────────────────────────────────────────────────

Future<void> _printVoucherSlipHelper({
  required BuildContext context,
  required String code,
  required ShotMode mode,
  required double price,
  required DateTime expiresAt,
}) async {
  try {
    final db = context.read<AppDatabase>();
    final printers = await db.getAllPrinters();
    final defaultPrinter = printers.where((p) => p.isDefault).firstOrNull;
    if (defaultPrinter != null && context.mounted) {
      final printerModel = PrinterModel(
        id: defaultPrinter.id,
        name: defaultPrinter.name,
        transport: defaultPrinter.transport == 'usb'
            ? PrinterTransport.usb
            : defaultPrinter.transport == 'bluetooth'
                ? PrinterTransport.bluetooth
                : PrinterTransport.network,
        address: defaultPrinter.address,
        paperWidthMm: defaultPrinter.paperWidthMm,
        isDefault: true,
      );
      await context.read<PrinterService>().printText(
            printer: printerModel,
            text: '================================\n'
                '       PHOTORECEIPT VOUCHER     \n'
                '================================\n'
                'CODE: $code\n'
                'TIER: ${mode.label} (${mode.photoCount} Photos)\n'
                'PRICE: ₱${price.toStringAsFixed(2)}\n'
                'EXPIRES: ${expiresAt.toString().substring(0, 16)}\n'
                '================================\n'
                'Type this code at the kiosk!\n\n',
          );
    }
  } catch (_) {}
}

Future<void> _exportExcelAndNotify({
  required BuildContext context,
  required Future<String?> Function() exportFn,
}) async {
  try {
    final path = await exportFn();
    if (!context.mounted) return;
    if (path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Exported: ${p.basename(path)}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Show in Folder',
            textColor: AppColors.primary,
            onPressed: () => ExcelExportService.openInExplorer(path),
          ),
        ),
      );
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Export failed: $e'),
        backgroundColor: AppColors.error,
      ),
    );
  }
}

class _VouchersSection extends StatefulWidget {
  final Map<String, String> settings;
  const _VouchersSection({required this.settings});

  @override
  State<_VouchersSection> createState() => _VouchersSectionState();
}

class _VouchersSectionState extends State<_VouchersSection> {
  late Future<List<VoucherEntry>> _vouchersFuture;
  String _activeTab = 'active'; // 'active', 'used', 'all'
  ShotMode? _selectedTier;
  int _currentPage = 0;
  int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadVouchers();
  }

  void _loadVouchers() {
    setState(() {
      _vouchersFuture = context.read<AppDatabase>().getAllVouchers();
    });
  }

  void _showGenerateDialog() async {
    final createdVouchers = await showDialog<List<VoucherModel>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _VoucherGenerationDialog(settings: widget.settings),
    );

    if (createdVouchers != null && createdVouchers.isNotEmpty && mounted) {
      _loadVouchers();
      _showBatchResultDialog(createdVouchers);
    }
  }

  void _showBatchResultDialog(List<VoucherModel> vouchers) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 28),
            const SizedBox(width: 12),
            Text(
              '${vouchers.length} Voucher${vouchers.length > 1 ? "s" : ""} Generated',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tier: ${vouchers.first.shotMode.label} • ₱${vouchers.first.priceSnapshot.toStringAsFixed(2)} each',
                style:
                    const TextStyle(color: AppColors.onSurface, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: vouchers.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Colors.white10),
                  itemBuilder: (ctx, i) {
                    final v = vouchers[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      title: SelectableText(
                        v.code,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 1.2),
                      ),
                      subtitle: Text(
                        'Expires: ${v.expiresAt.toString().substring(0, 16)}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.onSurface),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        tooltip: 'Copy',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: v.code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Copied ${v.code}')),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.table_view_rounded, size: 18),
            label: const Text('Download Excel'),
            onPressed: () => _exportExcelAndNotify(
              context: context,
              exportFn: () => ExcelExportService.exportVoucherBatch(vouchers),
            ),
          ),
          TextButton.icon(
            icon: const Icon(Icons.copy_all_rounded),
            label: const Text('Copy All Codes'),
            onPressed: () {
              final allText = vouchers.map((v) => v.code).join('\n');
              Clipboard.setData(ClipboardData(text: allText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('All voucher codes copied to clipboard!')),
              );
            },
          ),
          ElevatedButton(
            child: const Text('Done'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();

    return ListView(
      children: [
        // ── Top Header with Generate Button ─────────────────────────────────
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 620;
            final titleCol = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vouchers Management',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Generate voucher batches, track active unredeemed codes, and manage lifecycle.',
                  style: TextStyle(color: AppColors.onSurface),
                ),
              ],
            );

            final actionBtn = ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text('Generate Vouchers'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              onPressed: _showGenerateDialog,
            );

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleCol,
                  const SizedBox(height: 16),
                  actionBtn,
                ],
              );
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: titleCol),
                const SizedBox(width: 16),
                actionBtn,
              ],
            );
          },
        ),

        const SizedBox(height: 20),

        // ── Voucher Inventory Table & Filters ────────────────────────────────
        FutureBuilder<List<VoucherEntry>>(
          future: _vouchersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final all = (snapshot.data ?? []).reversed.toList();
            final filtered = all.where((v) {
              final matchesStatus =
                  _activeTab == 'all' ? true : v.status == _activeTab;
              final matchesTier = _selectedTier == null
                  ? true
                  : v.tierChar == _selectedTier!.tierChar;
              return matchesStatus && matchesTier;
            }).toList();

            final totalItems = filtered.length;
            final totalPages = (totalItems / _rowsPerPage).ceil();
            final validPage =
                totalPages == 0 ? 0 : _currentPage.clamp(0, totalPages - 1);
            final startIndex = validPage * _rowsPerPage;
            final endIndex = (startIndex + _rowsPerPage).clamp(0, totalItems);
            final pagedList = filtered.sublist(startIndex, endIndex);

            return Card(
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          Text(
                            'Vouchers List (${filtered.length})',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Status Dropdown
                              Container(
                                height: 38,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _activeTab,
                                    dropdownColor: AppColors.surfaceVariant,
                                    style: const TextStyle(
                                        fontSize: 13, color: Colors.white),
                                    icon: const Icon(Icons.arrow_drop_down,
                                        color: AppColors.onSurface, size: 20),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'active',
                                          child:
                                              Text('Status: Active (Unused)')),
                                      DropdownMenuItem(
                                          value: 'used',
                                          child:
                                              Text('Status: Used / Redeemed')),
                                      DropdownMenuItem(
                                          value: 'all',
                                          child: Text('Status: All Vouchers')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _activeTab = val;
                                          _currentPage = 0;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                              // Tier Dropdown
                              Container(
                                height: 38,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<ShotMode?>(
                                    value: _selectedTier,
                                    dropdownColor: AppColors.surfaceVariant,
                                    style: const TextStyle(
                                        fontSize: 13, color: Colors.white),
                                    icon: const Icon(Icons.arrow_drop_down,
                                        color: AppColors.onSurface, size: 20),
                                    items: [
                                      const DropdownMenuItem(
                                          value: null,
                                          child: Text('Tier: All Tiers')),
                                      ...ShotMode.values.map(
                                        (mode) => DropdownMenuItem(
                                          value: mode,
                                          child: Text('Tier: ${mode.label}'),
                                        ),
                                      ),
                                    ],
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedTier = val;
                                        _currentPage = 0;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.table_view_rounded,
                                    size: 16),
                                label: const Text('Export'),
                                onPressed: filtered.isEmpty
                                    ? null
                                    : () => _exportExcelAndNotify(
                                          context: context,
                                          exportFn: () => ExcelExportService
                                              .exportVouchersInventory(
                                            filtered,
                                            filterLabel:
                                                '${_activeTab}_${_selectedTier?.name ?? "all"}',
                                          ),
                                        ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Colors.white10),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 48, horizontal: 24),
                        child: Column(
                          children: [
                            Icon(
                              _activeTab == 'active'
                                  ? Icons.confirmation_number_outlined
                                  : Icons.inbox_rounded,
                              size: 54,
                              color: AppColors.onSurface.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _activeTab == 'active'
                                  ? 'No Active Unused Vouchers'
                                  : 'No Vouchers Found',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _activeTab == 'active'
                                  ? 'Tap "Generate Vouchers" to create new customer tickets.'
                                  : 'Try adjusting your filters above.',
                              style:
                                  const TextStyle(color: AppColors.onSurface),
                            ),
                          ],
                        ),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 24,
                          columns: const [
                            DataColumn(
                                label: Text('Voucher Code',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            DataColumn(
                                label: Text('Tier',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            DataColumn(
                                label: Text('Price',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            DataColumn(
                                label: Text('Created',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            DataColumn(
                                label: Text('Expires',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            DataColumn(
                                label: Text('Status',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            DataColumn(
                                label: Text('Actions',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                          ],
                          rows: pagedList.map((v) {
                            final isActive = v.status == 'active';
                            final isUsed = v.status == 'used';
                            final mode =
                                ShotModeExtension.fromTierChar(v.tierChar);

                            return DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SelectableText(
                                        v.code,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.8),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.copy_rounded,
                                            size: 16,
                                            color: AppColors.onSurface),
                                        tooltip: 'Copy Code',
                                        onPressed: () {
                                          Clipboard.setData(
                                              ClipboardData(text: v.code));
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content:
                                                    Text('Copied ${v.code}')),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      mode.label,
                                      style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12),
                                    ),
                                  ),
                                ),
                                DataCell(Text(
                                    '₱${v.priceSnapshot.toStringAsFixed(2)}')),
                                DataCell(Text(
                                    v.createdAt.toString().substring(0, 16))),
                                DataCell(Text(
                                    v.expiresAt.toString().substring(0, 16))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? AppColors.success
                                              .withValues(alpha: 0.2)
                                          : isUsed
                                              ? Colors.white12
                                              : AppColors.error
                                                  .withValues(alpha: 0.2),
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
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.print_rounded,
                                            size: 20),
                                        tooltip: 'Print Slip',
                                        onPressed: () async {
                                          await _printVoucherSlipHelper(
                                            context: context,
                                            code: v.code,
                                            mode: mode,
                                            price: v.priceSnapshot,
                                            expiresAt: v.expiresAt,
                                          );
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'Print job sent for ${v.code}')),
                                            );
                                          }
                                        },
                                      ),
                                      if (isActive)
                                        IconButton(
                                          icon: const Icon(Icons.block_rounded,
                                              size: 20, color: AppColors.error),
                                          tooltip: 'Void Voucher',
                                          onPressed: () async {
                                            final confirm =
                                                await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title:
                                                    const Text('Void Voucher?'),
                                                content: Text(
                                                    'Are you sure you want to void voucher ${v.code}? It can no longer be used.'),
                                                actions: [
                                                  TextButton(
                                                    child: const Text('Cancel'),
                                                    onPressed: () =>
                                                        Navigator.of(ctx)
                                                            .pop(false),
                                                  ),
                                                  ElevatedButton(
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                            backgroundColor:
                                                                AppColors
                                                                    .error),
                                                    child:
                                                        const Text('Void Code'),
                                                    onPressed: () =>
                                                        Navigator.of(ctx)
                                                            .pop(true),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              await db.updateVoucherStatus(
                                                  v.code, 'voided',
                                                  voidReason: 'Admin voided');
                                              _loadVouchers();
                                            }
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    if (filtered.isNotEmpty) ...[
                      const Divider(height: 1, color: Colors.white10),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 16,
                          runSpacing: 10,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Rows per page:',
                                  style: TextStyle(
                                    color: AppColors.onSurface,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  height: 32,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: _rowsPerPage,
                                      dropdownColor: AppColors.surfaceVariant,
                                      style: const TextStyle(
                                          fontSize: 13, color: Colors.white),
                                      icon: const Icon(Icons.arrow_drop_down,
                                          color: AppColors.onSurface, size: 18),
                                      items: const [
                                        DropdownMenuItem(
                                            value: 5, child: Text('5')),
                                        DropdownMenuItem(
                                            value: 10, child: Text('10')),
                                        DropdownMenuItem(
                                            value: 25, child: Text('25')),
                                        DropdownMenuItem(
                                            value: 50, child: Text('50')),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) {
                                          setState(() {
                                            _rowsPerPage = v;
                                            _currentPage = 0;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  totalItems == 0
                                      ? '0 of 0'
                                      : '${startIndex + 1}–$endIndex of $totalItems',
                                  style: const TextStyle(
                                    color: AppColors.onSurface,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(Icons.first_page_rounded,
                                      size: 20),
                                  tooltip: 'First Page',
                                  onPressed: validPage > 0
                                      ? () => setState(() => _currentPage = 0)
                                      : null,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_left_rounded,
                                      size: 20),
                                  tooltip: 'Previous Page',
                                  onPressed: validPage > 0
                                      ? () => setState(
                                          () => _currentPage = validPage - 1)
                                      : null,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  child: Text(
                                    'Page ${validPage + 1} of ${totalPages == 0 ? 1 : totalPages}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right_rounded,
                                      size: 20),
                                  tooltip: 'Next Page',
                                  onPressed: validPage < totalPages - 1
                                      ? () => setState(
                                          () => _currentPage = validPage + 1)
                                      : null,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.last_page_rounded,
                                      size: 20),
                                  tooltip: 'Last Page',
                                  onPressed: validPage < totalPages - 1
                                      ? () => setState(
                                          () => _currentPage = totalPages - 1)
                                      : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 32),
      ],
    );
  }
}

// ─── Voucher Generation Dialog ────────────────────────────────────────────────

class _VoucherGenerationDialog extends StatefulWidget {
  final Map<String, String> settings;
  const _VoucherGenerationDialog({required this.settings});

  @override
  State<_VoucherGenerationDialog> createState() =>
      _VoucherGenerationDialogState();
}

class _VoucherGenerationDialogState extends State<_VoucherGenerationDialog> {
  ShotMode _selectedMode = ShotMode.quad;
  final _countCtrl = TextEditingController(text: '1');
  bool _printSlips = true;
  bool _isGenerating = false;

  @override
  void dispose() {
    _countCtrl.dispose();
    super.dispose();
  }

  void _adjustCount(int delta) {
    final current = int.tryParse(_countCtrl.text.trim()) ?? 1;
    final next = (current + delta).clamp(1, 100);
    _countCtrl.text = next.toString();
  }

  Future<void> _generate() async {
    final count = int.tryParse(_countCtrl.text.trim()) ?? 0;
    if (count <= 0 || count > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a quantity between 1 and 100.')),
      );
      return;
    }

    setState(() => _isGenerating = true);
    final voucherService = context.read<VoucherService>();

    try {
      final vouchers = await voucherService.generateBatch(
        mode: _selectedMode,
        count: count,
      );

      if (_printSlips && mounted) {
        for (final v in vouchers) {
          await _printVoucherSlipHelper(
            context: context,
            code: v.code,
            mode: v.shotMode,
            price: v.priceSnapshot,
            expiresAt: v.expiresAt,
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop(vouchers);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Generation failed: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.confirmation_number_rounded,
              color: AppColors.primary, size: 28),
          SizedBox(width: 12),
          Text('Generate Customer Vouchers',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('1. Select Shot Mode / Tier:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: ShotMode.values.map((mode) {
                  final isSelected = _selectedMode == mode;
                  final priceKey = 'price_${mode.tierChar}';
                  final price = widget.settings[priceKey] ??
                      (mode == ShotMode.single
                          ? '50'
                          : mode == ShotMode.triple
                              ? '80'
                              : mode == ShotMode.quad
                                  ? '100'
                                  : '120');

                  return ChoiceChip(
                    showCheckmark: false,
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    label: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
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
                              fontSize: 11,
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
              const Text('2. How many vouchers would you like to generate?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              Row(
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.remove_rounded),
                    onPressed: () => _adjustCount(-1),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 90,
                    child: TextFormField(
                      controller: _countCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () => _adjustCount(1),
                  ),
                  const SizedBox(width: 16),
                  // Preset chips
                  Wrap(
                    spacing: 6,
                    children: [5, 10, 20].map((preset) {
                      return ActionChip(
                        label: Text('+$preset'),
                        onPressed: () {
                          final cur = int.tryParse(_countCtrl.text.trim()) ?? 0;
                          _countCtrl.text =
                              (cur + preset).clamp(1, 100).toString();
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.primary,
                title: const Text('Print thermal ticket slips immediately',
                    style: TextStyle(fontSize: 14)),
                value: _printSlips,
                onChanged: (v) => setState(() => _printSlips = v ?? true),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isGenerating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          icon: _isGenerating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.bolt_rounded),
          label: Text(_isGenerating ? 'Generating...' : 'Generate Now'),
          onPressed: _isGenerating ? null : _generate,
        ),
      ],
    );
  }
}

// ─── 7. Sales & Revenue Section ───────────────────────────────────────────────

enum _SalesDateFilter {
  today,
  yesterday,
  last7Days,
  thisMonth,
  allTime,
  custom,
}

class _SalesSection extends StatefulWidget {
  final Map<String, String> settings;
  const _SalesSection({required this.settings});

  @override
  State<_SalesSection> createState() => _SalesSectionState();
}

class _SalesSectionState extends State<_SalesSection> {
  late Future<List<VoucherEntry>> _vouchersFuture;
  _SalesDateFilter _dateFilter = _SalesDateFilter.allTime;
  DateTimeRange? _customRange;
  ShotMode? _selectedTier;
  int _currentPage = 0;
  int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  void _loadSales() {
    setState(() {
      _vouchersFuture = context.read<AppDatabase>().getAllVouchers();
    });
  }

  DateTimeRange? _resolveDateRange() {
    final now = DateTime.now();
    switch (_dateFilter) {
      case _SalesDateFilter.today:
        final start = DateTime(now.year, now.month, now.day);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
      case _SalesDateFilter.yesterday:
        final y = now.subtract(const Duration(days: 1));
        final start = DateTime(y.year, y.month, y.day);
        final end = DateTime(y.year, y.month, y.day, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
      case _SalesDateFilter.last7Days:
        final start = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 6));
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
      case _SalesDateFilter.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
      case _SalesDateFilter.allTime:
        return null;
      case _SalesDateFilter.custom:
        return _customRange;
    }
  }

  String _filterLabel() {
    switch (_dateFilter) {
      case _SalesDateFilter.today:
        return 'Today';
      case _SalesDateFilter.yesterday:
        return 'Yesterday';
      case _SalesDateFilter.last7Days:
        return 'Last 7 Days';
      case _SalesDateFilter.thisMonth:
        return 'This Month';
      case _SalesDateFilter.allTime:
        return 'All Time';
      case _SalesDateFilter.custom:
        if (_customRange != null) {
          return '${_customRange!.start.toString().substring(0, 10)} to ${_customRange!.end.toString().substring(0, 10)}';
        }
        return 'Custom Date Range';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Text(
          'Sales & Revenue Analytics',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        const Text(
          'Monitor used vouchers, track sales performance per tier mode, and analyze revenue.',
          style: TextStyle(color: AppColors.onSurface),
        ),
        const SizedBox(height: 20),

        // ── Data Content ─────────────────────────────────────────────────────
        FutureBuilder<List<VoucherEntry>>(
          future: _vouchersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final allVouchers = snapshot.data ?? [];
            final range = _resolveDateRange();

            // Filter to USED vouchers within the active date range
            final usedSales = allVouchers.where((v) {
              if (v.status != 'used') return false;
              final timestamp = v.redeemedAt ?? v.createdAt;
              if (range != null) {
                if (timestamp.isBefore(range.start) ||
                    timestamp.isAfter(range.end)) {
                  return false;
                }
              }
              return true;
            }).toList();

            // Aggregate metrics per tier
            int singleCount = 0;
            double singleRev = 0.0;
            int tripleCount = 0;
            double tripleRev = 0.0;
            int quadCount = 0;
            double quadRev = 0.0;
            int hexCount = 0;
            double hexRev = 0.0;

            for (final v in usedSales) {
              final tier = v.tierChar;
              final price = v.priceSnapshot;
              if (tier == ShotMode.single.tierChar) {
                singleCount++;
                singleRev += price;
              } else if (tier == ShotMode.triple.tierChar) {
                tripleCount++;
                tripleRev += price;
              } else if (tier == ShotMode.quad.tierChar) {
                quadCount++;
                quadRev += price;
              } else if (tier == ShotMode.hex.tierChar) {
                hexCount++;
                hexRev += price;
              }
            }

            final totalCount = usedSales.length;
            final totalRev = singleRev + tripleRev + quadRev + hexRev;

            // Tier filtering for table
            final tableSales = usedSales
                .where((v) {
                  if (_selectedTier == null) return true;
                  return v.tierChar == _selectedTier!.tierChar;
                })
                .toList()
                .reversed
                .toList();

            final totalItems = tableSales.length;
            final totalPages = (totalItems / _rowsPerPage).ceil();
            final validPage =
                totalPages == 0 ? 0 : _currentPage.clamp(0, totalPages - 1);
            final startIndex = validPage * _rowsPerPage;
            final endIndex = (startIndex + _rowsPerPage).clamp(0, totalItems);
            final pagedSales = tableSales.sublist(startIndex, endIndex);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Tier Summary Cards ──────────────────────────────────────
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final cardWidth = width < 700
                        ? (width - 12) / 2
                        : width < 1100
                            ? (width - 24) / 3
                            : (width - 48) / 5;

                    Widget metricCard({
                      required String title,
                      required String subtitle,
                      required int count,
                      required double revenue,
                      required IconData icon,
                      required Color color,
                      bool isPrimary = false,
                    }) {
                      return Container(
                        width: cardWidth,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isPrimary
                              ? color.withValues(alpha: 0.18)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isPrimary ? color : Colors.white10,
                            width: isPrimary ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isPrimary
                                        ? Colors.white
                                        : AppColors.onSurface,
                                  ),
                                ),
                                Icon(icon, size: 20, color: color),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '₱${revenue.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: isPrimary ? color : Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$count sold • $subtitle',
                              style: TextStyle(
                                fontSize: 12,
                                color: isPrimary
                                    ? Colors.white70
                                    : AppColors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        metricCard(
                          title: 'Single (1 photo)',
                          subtitle: '1 Shot',
                          count: singleCount,
                          revenue: singleRev,
                          icon: Icons.photo_camera_rounded,
                          color: Colors.blueAccent,
                        ),
                        metricCard(
                          title: '3 Shots (Triple)',
                          subtitle: '3 Photos',
                          count: tripleCount,
                          revenue: tripleRev,
                          icon: Icons.view_column_rounded,
                          color: Colors.purpleAccent,
                        ),
                        metricCard(
                          title: '4 Shots (Quad)',
                          subtitle: '4 Photos',
                          count: quadCount,
                          revenue: quadRev,
                          icon: Icons.grid_view_rounded,
                          color: Colors.tealAccent,
                        ),
                        metricCard(
                          title: '6 Shots (Hex)',
                          subtitle: '6 Photos',
                          count: hexCount,
                          revenue: hexRev,
                          icon: Icons.dashboard_rounded,
                          color: Colors.amberAccent,
                        ),
                        metricCard(
                          title: 'Total Sales',
                          subtitle: 'Gross revenue',
                          count: totalCount,
                          revenue: totalRev,
                          icon: Icons.savings_rounded,
                          color: AppColors.primary,
                          isPrimary: true,
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 24),

                // ── Sales History Card & Filters ─────────────────────────────
                Card(
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            runSpacing: 10,
                            children: [
                              Text(
                                'Redeemed Sales History (${tableSales.length})',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  // Date Filter Dropdown
                                  Container(
                                    height: 38,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<_SalesDateFilter>(
                                        value: _dateFilter,
                                        dropdownColor: AppColors.surfaceVariant,
                                        style: const TextStyle(
                                            fontSize: 13, color: Colors.white),
                                        icon: const Icon(Icons.arrow_drop_down,
                                            color: AppColors.onSurface,
                                            size: 20),
                                        items: [
                                          const DropdownMenuItem(
                                            value: _SalesDateFilter.today,
                                            child: Text('Date: Today'),
                                          ),
                                          const DropdownMenuItem(
                                            value: _SalesDateFilter.yesterday,
                                            child: Text('Date: Yesterday'),
                                          ),
                                          const DropdownMenuItem(
                                            value: _SalesDateFilter.last7Days,
                                            child: Text('Date: Last 7 Days'),
                                          ),
                                          const DropdownMenuItem(
                                            value: _SalesDateFilter.thisMonth,
                                            child: Text('Date: This Month'),
                                          ),
                                          const DropdownMenuItem(
                                            value: _SalesDateFilter.allTime,
                                            child: Text('Date: All Time'),
                                          ),
                                          DropdownMenuItem(
                                            value: _SalesDateFilter.custom,
                                            child: Text(
                                              _dateFilter ==
                                                          _SalesDateFilter
                                                              .custom &&
                                                      _customRange != null
                                                  ? 'Date: ${_customRange!.start.month}/${_customRange!.start.day}–${_customRange!.end.month}/${_customRange!.end.day}'
                                                  : 'Date: Custom Range…',
                                            ),
                                          ),
                                        ],
                                        onChanged: (val) async {
                                          if (val == _SalesDateFilter.custom) {
                                            final picked =
                                                await showDateRangePicker(
                                              context: context,
                                              firstDate: DateTime(2024),
                                              lastDate: DateTime.now().add(
                                                  const Duration(days: 365)),
                                              initialDateRange: _customRange ??
                                                  DateTimeRange(
                                                    start: DateTime.now()
                                                        .subtract(
                                                            const Duration(
                                                                days: 7)),
                                                    end: DateTime.now(),
                                                  ),
                                            );
                                            if (picked != null) {
                                              setState(() {
                                                _customRange = picked;
                                                _dateFilter =
                                                    _SalesDateFilter.custom;
                                                _currentPage = 0;
                                              });
                                            }
                                          } else if (val != null) {
                                            setState(() {
                                              _dateFilter = val;
                                              _currentPage = 0;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                  // Tier Dropdown
                                  Container(
                                    height: 38,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<ShotMode?>(
                                        value: _selectedTier,
                                        dropdownColor: AppColors.surfaceVariant,
                                        style: const TextStyle(
                                            fontSize: 13, color: Colors.white),
                                        icon: const Icon(Icons.arrow_drop_down,
                                            color: AppColors.onSurface,
                                            size: 20),
                                        items: [
                                          const DropdownMenuItem(
                                            value: null,
                                            child: Text('Tier: All Tiers'),
                                          ),
                                          ...ShotMode.values.map(
                                            (mode) => DropdownMenuItem(
                                              value: mode,
                                              child:
                                                  Text('Tier: ${mode.label}'),
                                            ),
                                          ),
                                        ],
                                        onChanged: (val) {
                                          setState(() {
                                            _selectedTier = val;
                                            _currentPage = 0;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.table_view_rounded,
                                        size: 16),
                                    label: const Text('Export'),
                                    onPressed: tableSales.isEmpty
                                        ? null
                                        : () => _exportExcelAndNotify(
                                              context: context,
                                              exportFn: () => ExcelExportService
                                                  .exportSalesReport(
                                                sales: tableSales,
                                                dateFilterLabel: _filterLabel(),
                                                tierFilterLabel:
                                                    _selectedTier?.label,
                                              ),
                                            ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Colors.white10),
                        if (tableSales.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 48, horizontal: 24),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.receipt_long_rounded,
                                  size: 50,
                                  color: AppColors.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No Sales Found for this Filter',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'No vouchers were redeemed during the ${_filterLabel().toLowerCase()} period.',
                                  style: const TextStyle(
                                      color: AppColors.onSurface),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columnSpacing: 28,
                              columns: const [
                                DataColumn(
                                    label: Text('Voucher Code',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                DataColumn(
                                    label: Text('Tier Mode',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                DataColumn(
                                    label: Text('Amount',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                DataColumn(
                                    label: Text('Redeemed At',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                DataColumn(
                                    label: Text('Created Date',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                DataColumn(
                                    label: Text('Actions',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                              ],
                              rows: pagedSales.map((v) {
                                final mode =
                                    ShotModeExtension.fromTierChar(v.tierChar);
                                final redeemedStr = v.redeemedAt != null
                                    ? v.redeemedAt.toString().substring(0, 16)
                                    : '—';

                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SelectableText(
                                            v.code,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.8),
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            icon: const Icon(Icons.copy_rounded,
                                                size: 16,
                                                color: AppColors.onSurface),
                                            tooltip: 'Copy Code',
                                            onPressed: () {
                                              Clipboard.setData(
                                                  ClipboardData(text: v.code));
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                    content: Text(
                                                        'Copied ${v.code}')),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          mode.label,
                                          style: const TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        '₱${v.priceSnapshot.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    DataCell(Text(redeemedStr)),
                                    DataCell(Text(v.createdAt
                                        .toString()
                                        .substring(0, 16))),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.print_rounded,
                                            size: 20),
                                        tooltip: 'Print Receipt Copy',
                                        onPressed: () async {
                                          await _printVoucherSlipHelper(
                                            context: context,
                                            code: v.code,
                                            mode: mode,
                                            price: v.priceSnapshot,
                                            expiresAt: v.expiresAt,
                                          );
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'Receipt printed for ${v.code}')),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                          const Divider(height: 1, color: Colors.white10),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 16,
                              runSpacing: 10,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Rows per page:',
                                      style: TextStyle(
                                        color: AppColors.onSurface,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      height: 32,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceVariant,
                                        borderRadius: BorderRadius.circular(6),
                                        border:
                                            Border.all(color: Colors.white12),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<int>(
                                          value: _rowsPerPage,
                                          dropdownColor:
                                              AppColors.surfaceVariant,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.white),
                                          icon: const Icon(
                                              Icons.arrow_drop_down,
                                              color: AppColors.onSurface,
                                              size: 18),
                                          items: const [
                                            DropdownMenuItem(
                                                value: 5, child: Text('5')),
                                            DropdownMenuItem(
                                                value: 10, child: Text('10')),
                                            DropdownMenuItem(
                                                value: 25, child: Text('25')),
                                            DropdownMenuItem(
                                                value: 50, child: Text('50')),
                                          ],
                                          onChanged: (v) {
                                            if (v != null) {
                                              setState(() {
                                                _rowsPerPage = v;
                                                _currentPage = 0;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      totalItems == 0
                                          ? '0 of 0'
                                          : '${startIndex + 1}–$endIndex of $totalItems',
                                      style: const TextStyle(
                                        color: AppColors.onSurface,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    IconButton(
                                      icon: const Icon(Icons.first_page_rounded,
                                          size: 20),
                                      tooltip: 'First Page',
                                      onPressed: validPage > 0
                                          ? () =>
                                              setState(() => _currentPage = 0)
                                          : null,
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.chevron_left_rounded,
                                          size: 20),
                                      tooltip: 'Previous Page',
                                      onPressed: validPage > 0
                                          ? () => setState(() =>
                                              _currentPage = validPage - 1)
                                          : null,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      child: Text(
                                        'Page ${validPage + 1} of ${totalPages == 0 ? 1 : totalPages}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.chevron_right_rounded,
                                          size: 20),
                                      tooltip: 'Next Page',
                                      onPressed: validPage < totalPages - 1
                                          ? () => setState(() =>
                                              _currentPage = validPage + 1)
                                          : null,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.last_page_rounded,
                                          size: 20),
                                      tooltip: 'Last Page',
                                      onPressed: validPage < totalPages - 1
                                          ? () => setState(() =>
                                              _currentPage = totalPages - 1)
                                          : null,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
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
  late final TextEditingController _locationIdCtrl;
  late final TextEditingController _voucherSecretCtrl;
  bool _obscure = true;
  bool _isUpdatingPw = false;
  bool _isSavingLocation = false;

  @override
  void initState() {
    super.initState();
    _locationIdCtrl = TextEditingController(
      text: widget.settings['location_id'] ?? 'MNL1',
    );
    _voucherSecretCtrl = TextEditingController(
      text: widget.settings['voucher_secret'] ?? '',
    );
  }

  @override
  void dispose() {
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    _locationIdCtrl.dispose();
    _voucherSecretCtrl.dispose();
    super.dispose();
  }

  void _saveLocationAndSecret() {
    setState(() => _isSavingLocation = true);
    final locId = _locationIdCtrl.text.trim();
    final secret = _voucherSecretCtrl.text.trim();

    context.read<AdminBloc>().add(
          AdminMultipleSettingsUpdated({
            'location_id': locId,
            'voucher_secret': secret,
          }),
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location & Voucher Secret saved successfully!'),
        backgroundColor: AppColors.success,
      ),
    );

    setState(() => _isSavingLocation = false);
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
                    prefixIcon: Icon(Icons.check_circle_outline_rounded),
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
                Text('Kiosk Location ID',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _locationIdCtrl,
                  decoration: const InputDecoration(hintText: 'e.g. MNL1'),
                ),
                const SizedBox(height: 20),
                Text('Voucher Cryptographic Secret Key',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _voucherSecretCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Secret HMAC key used for checksum verification',
                  ),
                ),
                const SizedBox(height: 12),
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
                    setState(() {
                      _voucherSecretCtrl.text = hex;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'New voucher secret generated! Tap "Save Location & Secret" to apply.',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: _isSavingLocation
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(_isSavingLocation
                        ? 'Saving...'
                        : 'Save Location & Secret'),
                    onPressed:
                        _isSavingLocation ? null : _saveLocationAndSecret,
                  ),
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
