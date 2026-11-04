import 'package:flutter_test/flutter_test.dart';
import 'package:picnprint/core/models/models.dart';
import 'package:picnprint/core/services/pricing_service.dart';
import 'package:picnprint/features/layout/bloc/layout_bloc.dart';
import 'package:picnprint/features/layout/bloc/layout_state.dart';

void main() {
  group('ShotMode Tiers Tests (2 Shots and 8 Shots)', () {
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

    test('LayoutBloc assigned layouts match specifications', () {
      final doubleBloc = LayoutBloc(shotMode: ShotMode.double);
      expect(doubleBloc.state, isA<LayoutInitial>());
      final doubleInitial = doubleBloc.state as LayoutInitial;
      expect(doubleInitial.availableLayouts, [LayoutType.verticalStrip]);

      final octaBloc = LayoutBloc(shotMode: ShotMode.octa);
      expect(octaBloc.state, isA<LayoutInitial>());
      final octaInitial = octaBloc.state as LayoutInitial;
      expect(octaInitial.availableLayouts, [
        LayoutType.grid2x4,
        LayoutType.bendo,
      ]);
    });
  });
}
