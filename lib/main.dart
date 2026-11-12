import 'package:device_preview_plus/device_preview_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/database/app_database.dart';
import 'core/router/app_router.dart';
import 'core/services/pricing_service.dart';
import 'core/services/voucher_service.dart';
import 'core/services/composition_service.dart';
import 'core/services/storage_service.dart';
import 'core/services/supabase_storage_service.dart';
import 'core/services/printer_service.dart';
import 'core/services/security_service.dart';
import 'core/theme/app_theme.dart';

import 'features/attract/bloc/attract_bloc.dart';
import 'features/voucher/bloc/voucher_bloc.dart';
import 'features/admin/bloc/admin_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Create the database (single instance for the whole app) ──────────────
  final db = AppDatabase();

  // ── Run 7-day cleanup on startup ─────────────────────────────────────────
  final storageService = StorageService(db);
  storageService.runCleanup().catchError((_) {});

  final supabaseStorageService = SupabaseStorageService(db);
  supabaseStorageService.runCleanup().catchError((_) {});

  // ── Check first-run ───────────────────────────────────────────────────────
  // (FirstRunScreen check happens in AttractScreen — if no password is set,
  //  the admin route redirects to /first-run)
  runApp(
    DevicePreview(
      enabled: kDebugMode,
      builder: (context) => MyApp(
        db: db,
        storageService: storageService,
        supabaseStorageService: supabaseStorageService,
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final AppDatabase db;
  final StorageService storageService;
  final SupabaseStorageService supabaseStorageService;

  MyApp({
    super.key,
    required this.db,
    required this.storageService,
    SupabaseStorageService? supabaseStorageService,
  }) : supabaseStorageService =
            supabaseStorageService ?? SupabaseStorageService(db);

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
        RepositoryProvider<SupabaseStorageService>.value(
            value: supabaseStorageService),
        RepositoryProvider(create: (_) => PrinterService()),
        RepositoryProvider(create: (_) => SecurityService(db)),
      ],
      child: MultiBlocProvider(
        // ── App-level blocs (survive screen changes) ─────────────────────
        providers: [
          // AttractBloc manages the idle slideshow and tap-to-start
          BlocProvider(create: (_) => AttractBloc()),

          // VoucherBloc is app-level so it persists across voucher attempts
          BlocProvider(
              create: (ctx) => VoucherBloc(
                    voucherService: ctx.read<VoucherService>(),
                  )),

          // AdminBloc is app-level so its locked/unlocked state is retained
          BlocProvider(
              create: (ctx) => AdminBloc(
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
      title: 'PicnSlip',
      debugShowCheckedModeBanner: false,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      themeMode: ThemeMode.light,
      theme: AppTheme.light.copyWith(
        textTheme: GoogleFonts.bricolageGrotesqueTextTheme(
          AppTheme.light.textTheme,
        ),
      ),
      darkTheme: AppTheme.dark.copyWith(
        textTheme: GoogleFonts.bricolageGrotesqueTextTheme(
          AppTheme.dark.textTheme,
        ),
      ),
      routerConfig: _router,
    );
  }
}
