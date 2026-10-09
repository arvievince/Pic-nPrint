import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/security_service.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';

/// First-run setup wizard — shown when no admin password is set.
///
/// Steps:
///   1. Set location ID
///   2. Set voucher secret
///   3. Create admin password
///
/// On completion → navigates to /admin (already unlocked).
///
class FirstRunScreen extends StatefulWidget {
  const FirstRunScreen({super.key});

  @override
  State<FirstRunScreen> createState() => _FirstRunScreenState();
}

class _FirstRunScreenState extends State<FirstRunScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  final _locationCtrl = TextEditingController();
  final _secretCtrl   = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();

  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _pageController.dispose();
    _locationCtrl.dispose();
    _secretCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              // Progress dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? AppColors.primary
                        : AppColors.onSurface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )),
              ),
              const SizedBox(height: 40),

              // Pages
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  children: [
                    _Page(
                      icon: Icons.location_on_rounded,
                      title: 'Set Location ID',
                      subtitle: 'A short code identifying this kiosk, e.g. MNL1',
                      child: TextField(
                        controller: _locationCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(labelText: 'Location ID'),
                      ),
                    ),
                    _Page(
                      icon: Icons.key_rounded,
                      title: 'Voucher Secret',
                      subtitle: 'A secret key used to sign voucher codes. Keep it safe.',
                      child: TextField(
                        controller: _secretCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Secret Key'),
                      ),
                    ),
                    _Page(
                      icon: Icons.lock_rounded,
                      title: 'Admin Password',
                      subtitle: 'Set a password to protect the admin panel.',
                      child: Column(
                        children: [
                          TextField(
                            controller: _passwordCtrl,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              errorText: _error,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _confirmCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Confirm Password',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Navigation buttons
              Row(
                children: [
                  if (_currentPage > 0)
                    OutlinedButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _saving ? null : _onNext,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          )
                        : Text(_currentPage == 2 ? 'Finish Setup' : 'Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onNext() async {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    // Final step — validate and save
    if (_passwordCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    if (_passwordCtrl.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }

    setState(() { _saving = true; _error = null; });

    try {
      final db = context.read();
      final security = context.read<SecurityService>();

      await db.setSetting('location_id', _locationCtrl.text.trim().toUpperCase());
      await db.setSetting('voucher_secret', _secretCtrl.text.trim());
      await security.setPassword(_passwordCtrl.text);

      if (mounted) context.goNamed(AppRoute.admin);
    } catch (e) {
      setState(() { _saving = false; _error = 'Setup failed: $e'; });
    }
  }
}

class _Page extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _Page({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icon, size: 64, color: AppColors.primary),
        const SizedBox(height: 20),
        Text(title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 40),
        child,
      ],
    );
  }
}
