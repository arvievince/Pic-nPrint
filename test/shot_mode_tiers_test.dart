import 'package:flutter_test/flutter_test.dart';
import 'package:picnprint/core/models/models.dart';
import 'package:picnprint/core/services/pricing_service.dart';

void main() {
  group('ShotMode Tiers & In-Editor Layout Tests', () {
    test('Double tier (2 shots) specifications', () {
      const mode = ShotMode.double;
      expect(mode.photoCount, 2);
      expect(mode.tierChar, 'D');
      expect(mode.label, 'Double');
      expect(ShotModeExtension.fromTierChar('D'), ShotMode.double);
      expect(ShotModeExtension.fromTierChar('d'), ShotMode.double);
    });

    test('8 Pack tier (8 shots) specifications', () {
      const mode = ShotMode.octa;
      expect(mode.photoCount, 8);
      expect(mode.tierChar, 'O');
      expect(mode.label, '8 Pack');
      expect(ShotModeExtension.fromTierChar('O'), ShotMode.octa);
      expect(ShotModeExtension.fromTierChar('o'), ShotMode.octa);
    });

    test('PricingService contains default prices for all shot modes', () {
      expect(PricingService.defaultPrices[ShotMode.single], 50.0);
      expect(PricingService.defaultPrices[ShotMode.double], 65.0);
      expect(PricingService.defaultPrices[ShotMode.triple], 80.0);
      expect(PricingService.defaultPrices[ShotMode.quad], 100.0);
      expect(PricingService.defaultPrices[ShotMode.hex], 120.0);
      expect(PricingService.defaultPrices[ShotMode.octa], 150.0);
    });

    test('All 11 photobooth theme layouts exist and Bento requires > 2 photos', () {
      expect(LayoutType.values.length, 11);

      // 1 and 2 shots: Bento must NOT be available (10 layouts)
      for (final count in [1, 2]) {
        final available = LayoutType.values
            .where((l) => l.isAvailableForCount(count))
            .toList();
        expect(available.contains(LayoutType.bento), isFalse);
        expect(available.length, 10);
      }

      // 3, 4, 6, 8 shots: Bento IS available (all 11 layouts)
      for (final count in [3, 4, 6, 8]) {
        final available = LayoutType.values
            .where((l) => l.isAvailableForCount(count))
            .toList();
        expect(available.contains(LayoutType.bento), isTrue);
        expect(available.length, 11);
      }
    });

    test('SessionModel.aspectRatioFor returns valid positive ratios for all layouts & tiers', () {
      for (final mode in ShotMode.values) {
        final count = mode.photoCount;
        for (final layout in LayoutType.values) {
          if (!layout.isAvailableForCount(count)) continue;
          final ratio = SessionModel.aspectRatioFor(layout, count);
          expect(ratio, greaterThan(0.0));
          expect(ratio, lessThan(3.5));
        }
      }
    });
  });
}
