import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:picnprint/core/database/app_database.dart';
import 'package:picnprint/core/services/voucher_service.dart';
import 'package:picnprint/features/voucher/bloc/voucher_bloc.dart';
import 'package:picnprint/features/voucher/view/voucher_screen.dart';

void main() {
  testWidgets('VoucherScreen native keyboard typing (default toggle OFF)',
      (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final voucherService = VoucherService(db);
    final voucherBloc = VoucherBloc(voucherService: voucherService);

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AppDatabase>.value(value: db),
          RepositoryProvider.value(value: voucherService),
        ],
        child: BlocProvider.value(
          value: voucherBloc,
          child: const MaterialApp(
            home: VoucherScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final textFieldFinder = find.byType(TextField);
    expect(textFieldFinder, findsOneWidget);

    // Default toggle is OFF -> on-screen keypad is hidden
    expect(find.byIcon(Icons.backspace_outlined), findsNothing);

    // Native text input (laptop keyboard or Android virtual keyboard)
    await tester.enterText(textFieldFinder, 'MNL1-S-00001-A1B2');
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(textFieldFinder);
    expect(textField.controller?.text, 'MNL1-S-00001-A1B2');

    await db.close();
  });

  testWidgets('VoucherScreen shows on-screen keypad when toggle is ON',
      (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.setSetting('show_onscreen_keyboard', 'true');

    final voucherService = VoucherService(db);
    final voucherBloc = VoucherBloc(voucherService: voucherService);

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AppDatabase>.value(value: db),
          RepositoryProvider.value(value: voucherService),
        ],
        child: BlocProvider.value(
          value: voucherBloc,
          child: const MaterialApp(
            home: VoucherScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Keypad is visible because toggle is ON
    expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);

    // Tap on-screen keypad button 'M'
    final keyM = find.widgetWithText(InkWell, 'M');
    expect(keyM, findsWidgets);
    await tester.tap(keyM.first);
    await tester.pumpAndSettle();

    final textFieldFinder = find.byType(TextField);
    var textField = tester.widget<TextField>(textFieldFinder);
    expect(textField.controller?.text, 'M');

    // Tap on-screen backspace
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pumpAndSettle();

    textField = tester.widget<TextField>(textFieldFinder);
    expect(textField.controller?.text, '');

    await db.close();
  });
}
