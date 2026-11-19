import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:picnprint/core/models/enums.dart';

import '../bloc/voucher_bloc.dart';
import '../bloc/voucher_event.dart';
import '../bloc/voucher_state.dart';
import '../../../core/database/app_database.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';

/// Customer enters their voucher code here.
///
/// Features:
///   - Native physical keyboard (laptop) & Android virtual keyboard input.
///   - Optional on-screen touchscreen keyboard for kiosks (Admin toggle).
///   - Clear & Paste quick action buttons.
///   - Format enforcement (uppercase letters, digits, dashes).
///   - On submit → VoucherBloc validates the code.
///   - On [VoucherValid] → navigates to /capture or /layout.
///   - On [VoucherInvalid] → shows inline error.
///   - On [VoucherLocked] → shows lockout screen.
class VoucherScreen extends StatefulWidget {
  const VoucherScreen({super.key});

  @override
  State<VoucherScreen> createState() => _VoucherScreenState();
}

class _VoucherScreenState extends State<VoucherScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _showOnScreenKeyboard = false;
  /// isColorPrint forwarded from TierSelectionScreen via route extra.
  bool _isColorPrint = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChange);
    _loadKeyboardSetting();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<VoucherBloc>().add(const VoucherReset());
        _focusNode.requestFocus();
        // Read isColorPrint from route extra if forwarded by TierSelectionScreen
        try {
          final extra = GoRouterState.of(context).extra;
          if (extra is Map<String, dynamic> &&
              extra.containsKey('isColorPrint')) {
            setState(() => _isColorPrint = extra['isColorPrint'] as bool? ?? false);
          }
        } catch (_) {}
      }
    });
  }

  Future<void> _loadKeyboardSetting() async {
    try {
      final db = context.read<AppDatabase>();
      final val = await db.getSetting('show_onscreen_keyboard');
      if (mounted) {
        setState(() {
          _showOnScreenKeyboard = val?.toLowerCase() == 'true';
        });
      }
    } catch (_) {}
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && data!.text!.trim().isNotEmpty) {
        final pasted = data.text!.trim().toUpperCase();
        _controller.text = pasted;
        _controller.selection = TextSelection.collapsed(offset: pasted.length);
        if (mounted) {
          context.read<VoucherBloc>().add(VoucherCodeChanged(pasted));
        }
      }
    } catch (_) {}
  }

  void _clearText() {
    _controller.clear();
    context.read<VoucherBloc>().add(const VoucherCodeChanged(''));
    _focusNode.requestFocus();
  }

  void _onKeyTap(String char) {
    final current = _controller.text;
    final updated = current + char.toUpperCase();
    _controller.text = updated;
    _controller.selection = TextSelection.collapsed(offset: updated.length);
    context.read<VoucherBloc>().add(VoucherCodeChanged(updated));
    _focusNode.requestFocus();
  }

  void _onBackspace() {
    final current = _controller.text;
    if (current.isNotEmpty) {
      final updated = current.substring(0, current.length - 1);
      _controller.text = updated;
      _controller.selection = TextSelection.collapsed(offset: updated.length);
      context.read<VoucherBloc>().add(VoucherCodeChanged(updated));
    }
    _focusNode.requestFocus();
  }

  void _submit(BuildContext context) {
    final code = _controller.text.trim();
    context.read<VoucherBloc>().add(VoucherSubmitted(code));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<VoucherBloc, VoucherState>(
      listener: (context, state) {
        if (state is VoucherValid) {
          final session = context
              .read<VoucherBloc>()
              .buildSession(state.voucher)
              .copyWith(isColorPrint: _isColorPrint);
          if (session.shotMode.photoCount == 1) {
            context.goNamed(AppRoute.capture, extra: session);
          } else {
            context.goNamed(AppRoute.layout, extra: session);
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Enter Voucher Code'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => context.goNamed(AppRoute.tierSelect),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_rounded),
              tooltip: 'Admin Panel',
              onPressed: () => context.goNamed(AppRoute.admin),
            ),
          ],
        ),
        body: BlocBuilder<VoucherBloc, VoucherState>(
          builder: (context, state) {
            if (state is VoucherLocked) {
              return _LockedView(remainingSeconds: state.remainingSeconds);
            }

            return Center(
              child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 580),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Icon ─────────────────────────────────────────────────
                        const Icon(
                          Icons.confirmation_number_rounded,
                          size: 64,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 16),

                        // ── Heading ───────────────────────────────────────────────
                        Text(
                          'Enter Your Code',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Please enter the voucher code printed on your receipt slip below to get started.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),

                        // ── Code Input ────────────────────────────────────────────
                        TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          autofocus: true,
                          mouseCursor: SystemMouseCursors.text,
                          enableInteractiveSelection: true,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[a-zA-Z0-9\-]')),
                            TextInputFormatter.withFunction(
                                (oldValue, newValue) {
                              return newValue.copyWith(
                                text: newValue.text.toUpperCase(),
                              );
                            }),
                          ],
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3,
                            color: AppColors.onBackground,
                          ),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: 'MNL1-F-00042-A7K9',
                            hintStyle: const TextStyle(
                              letterSpacing: 2,
                              color: AppColors.onSurface,
                              fontWeight: FontWeight.w400,
                            ),
                            errorText: state is VoucherInvalid
                                ? state.errorMessage
                                : null,
                            errorStyle: const TextStyle(
                              color: AppColors.error,
                              fontSize: 14,
                            ),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.content_paste_rounded,
                                    color: AppColors.primary,
                                  ),
                                  tooltip: 'Paste from clipboard',
                                  onPressed: _pasteFromClipboard,
                                ),
                                if (_controller.text.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.clear_rounded,
                                      color: AppColors.onSurface,
                                    ),
                                    tooltip: 'Clear',
                                    onPressed: _clearText,
                                  ),
                              ],
                            ),
                          ),
                          onChanged: (v) => context.read<VoucherBloc>().add(
                                VoucherCodeChanged(v),
                              ),
                          onSubmitted: (_) => _submit(context),
                        ),

                        const SizedBox(height: 16),

                        // ── Submit Button ─────────────────────────────────────────
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: state is VoucherValidating
                                ? null
                                : () => _submit(context),
                            child: state is VoucherValidating
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Validate Code'),
                          ),
                        ),

                        // ── Optional On-Screen Kiosk Keypad ─────────────────────
                        if (_showOnScreenKeyboard) ...[
                          const SizedBox(height: 24),
                          _OnScreenKeypad(
                            onKey: _onKeyTap,
                            onBackspace: _onBackspace,
                            onPaste: _pasteFromClipboard,
                            onClear: _clearText,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
        ),
      ),
    );
  }
}

/// A compact, responsive on-screen virtual keyboard for kiosks.
class _OnScreenKeypad extends StatelessWidget {
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback onPaste;
  final VoidCallback onClear;

  const _OnScreenKeypad({
    required this.onKey,
    required this.onBackspace,
    required this.onPaste,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    const row1 = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
    const row2 = ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'];
    const row3 = ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'];
    const row4 = ['Z', 'X', 'C', 'V', 'B', 'N', 'M'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Numbers
          _buildKeyRow(row1),
          const SizedBox(height: 8),
          // Row 2: QWERTY
          _buildKeyRow(row2),
          const SizedBox(height: 8),
          // Row 3: ASDF
          _buildKeyRow(row3),
          const SizedBox(height: 8),
          // Row 4: ZXCV + Dash + Backspace
          Row(
            children: [
              ...row4.map((k) => Expanded(child: _buildKey(k))),
              Expanded(
                child: _buildSpecialKey(
                  label: '-',
                  onTap: () => onKey('-'),
                ),
              ),
              Expanded(
                flex: 1,
                child: _buildSpecialKey(
                  icon: Icons.backspace_outlined,
                  onTap: onBackspace,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Row 5: Quick utility row (Paste & Clear)
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.onBackground,
                      side: const BorderSide(color: AppColors.cardBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    icon: const Icon(Icons.content_paste_rounded, size: 16),
                    label: const Text(
                      'Paste Clipboard',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    onPressed: onPaste,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.onBackground,
                      side: const BorderSide(color: AppColors.cardBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    icon: const Icon(Icons.clear_all_rounded, size: 16),
                    label: const Text(
                      'Clear',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    onPressed: onClear,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeyRow(List<String> keys) {
    return Row(
      children: keys
          .map(
            (k) => Expanded(
              child: _buildKey(k),
            ),
          )
          .toList(),
    );
  }

  Widget _buildKey(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        elevation: 0.5,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onKey(label),
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.onBackground,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialKey({
    String? label,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        elevation: 0.5,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: icon != null
                ? Icon(icon, size: 18, color: AppColors.onBackground)
                : Text(
                    label ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onBackground,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Shown when the user has exceeded failed attempts.
class _LockedView extends StatelessWidget {
  final int remainingSeconds;
  const _LockedView({required this.remainingSeconds});

  @override
  Widget build(BuildContext context) {
    final mins = remainingSeconds ~/ 60;
    final secs = (remainingSeconds % 60).toString().padLeft(2, '0');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 80,
              color: AppColors.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Too Many Attempts',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Please wait $mins:$secs before trying again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
