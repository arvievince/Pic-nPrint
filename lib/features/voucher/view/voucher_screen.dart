import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:picnprint/core/models/enums.dart';

import '../bloc/voucher_bloc.dart';
import '../bloc/voucher_event.dart';
import '../bloc/voucher_state.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';

/// Customer enters their voucher code here.
///
/// What it does:
///   - Shows a text field for code input (format hint: MNL1-F-00042-A7K9).
///   - On submit → VoucherBloc validates the code.
///   - On [VoucherValid] → navigates to /capture with the created session.
///   - On [VoucherInvalid] → shows inline error.
///   - On [VoucherLocked] → shows lockout screen.
///
class VoucherScreen extends StatefulWidget {
  const VoucherScreen({super.key});

  @override
  State<VoucherScreen> createState() => _VoucherScreenState();
}

class _VoucherScreenState extends State<VoucherScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<VoucherBloc>().add(const VoucherReset());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<VoucherBloc, VoucherState>(
      listener: (context, state) {
        if (state is VoucherValid) {
          // Build the session directly from the validated voucher
          final session = context.read<VoucherBloc>().buildSession(state.voucher);
          // For single-shot: go straight to capture
          // For multi-shot: go to layout selection first
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
            onPressed: () => context.goNamed(AppRoute.attract),
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
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Icon ─────────────────────────────────────────────────
                      const Icon(
                        Icons.confirmation_number_rounded,
                        size: 72,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 24),

                      // ── Heading ───────────────────────────────────────────────
                      Text(
                        'Enter Your Code',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your cashier gave you a voucher code.\nEnter it below to get started.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 40),

                      // ── Code Input ────────────────────────────────────────────
                      TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4,
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
                          suffixIcon: _controller.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    color: AppColors.onSurface,
                                  ),
                                  onPressed: () {
                                    _controller.clear();
                                    context.read<VoucherBloc>().add(
                                      const VoucherCodeChanged(''),
                                    );
                                  },
                                )
                              : null,
                        ),
                        onChanged: (v) => context.read<VoucherBloc>().add(
                          VoucherCodeChanged(v),
                        ),
                        onSubmitted: (_) => _submit(context),
                      ),

                      const SizedBox(height: 32),

                      // ── Submit Button ─────────────────────────────────────────
                      SizedBox(
                        height: 56,
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

  void _submit(BuildContext context) {
    context.read<VoucherBloc>().add(const VoucherSubmitted());
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
