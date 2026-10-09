import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:picnprint/core/database/app_database.dart';
import 'package:picnprint/core/services/storage_service.dart';
import 'package:picnprint/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    final inMemoryDb = AppDatabase.forTesting(NativeDatabase.memory());
    final storageService = StorageService(inMemoryDb);

    await tester.pumpWidget(
      MyApp(db: inMemoryDb, storageService: storageService),
    );

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(MyApp), findsOneWidget);
    await inMemoryDb.close();
  });
}
