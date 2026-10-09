import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/database/app_database.dart';
import 'core/router/app_router.dart';
import 'core/services/pricing_service.dart';
import 'core/services/voucher_service.dart';
import 'core/services/composition_service.dart';
import 'core/services/storage_service.dart';
import 'core/services/printer_service.dart';
import 'core/services/security_service.dart';
import 'core/theme/app_theme.dart';

import 'features/attract/bloc/attract_bloc.dart';
import 'features/voucher/bloc/voucher_bloc.dart';
import 'features/admin/bloc/admin_bloc.dart';

/// ─── App Entry Point ─────────────────────────────────────────────────────────
///
/// Architecture overview:
///   main.dart
///     └─ MultiRepositoryProvider (services + DB — long-lived singletons)
///         └─ MultiBlocProvider (app-level blocs — AttractBloc, AdminBloc)
///             └─ MaterialApp.router (GoRouter from app_router.dart)
///
/// Feature-specific blocs (CaptureBloc, EditorBloc, OutputBloc, LayoutBloc)
/// are created directly inside their own screen widgets using BlocProvider,
/// so they are scoped to that screen's lifetime only.
///
/// Services are provided via RepositoryProvider so any widget can access
/// them with context.read&lt;ServiceType&gt;().
///
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Create the database (single instance for the whole app) ──────────────
  final db = AppDatabase();

  // ── Run 7-day cleanup on startup ─────────────────────────────────────────
  final storageService = StorageService(db);
  storageService.runCleanup().catchError((_) {});

  // ── Check first-run ───────────────────────────────────────────────────────
  // (FirstRunScreen check happens in AttractScreen — if no password is set,
  //  the admin route redirects to /first-run)

  runApp(MyApp(db: db, storageService: storageService));
}

class MyApp extends StatelessWidget {
  final AppDatabase    db;
  final StorageService storageService;

  const MyApp({super.key, required this.db, required this.storageService});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      // ── Services (long-lived, one instance each) ─────────────────────────
      providers: [
        RepositoryProvider<AppDatabase>.value(value: db),
        RepositoryProvider(create: (_) => PricingService(db)),
        RepositoryProvider(create: (_) => VoucherService(db)),
        RepositoryProvider(create: (_) => CompositionService()),
        RepositoryProvider<StorageService>.value(value: storageService),
        RepositoryProvider(create: (_) => PrinterService()),
        RepositoryProvider(create: (_) => SecurityService(db)),
      ],
      child: MultiBlocProvider(
        // ── App-level blocs (survive screen changes) ─────────────────────
        providers: [
          // AttractBloc manages the idle slideshow and tap-to-start
          BlocProvider(create: (_) => AttractBloc()),

          // VoucherBloc is app-level so it persists across voucher attempts
          BlocProvider(create: (ctx) => VoucherBloc(
            voucherService: ctx.read<VoucherService>(),
          )),

          // AdminBloc is app-level so its locked/unlocked state is retained
          BlocProvider(create: (ctx) => AdminBloc(
            securityService: ctx.read<SecurityService>(),
            db: ctx.read<AppDatabase>(),
          )),
        ],
        child: _RouterApp(),
      ),
    );
  }
}

class _RouterApp extends StatefulWidget {
  @override
  State<_RouterApp> createState() => _RouterAppState();
}

class _RouterAppState extends State<_RouterApp> {
  late final _router = createRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PhotoReceipt',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: _router,
    );
  }
}
