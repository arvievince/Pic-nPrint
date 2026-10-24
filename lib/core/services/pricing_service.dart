import '../database/app_database.dart';
import '../models/enums.dart';

/// Returns the configured price for each shot mode.
///
/// Flow:
///   VoucherBloc → PricingService.getPriceForMode(mode) → price in PHP
///
/// The admin sets prices in AdminScreen → AdminBloc → PricingService.setPrice()
class PricingService {
  final AppDatabase _db;

  /// Default baseline prices for each shot mode in PHP.
  static const Map<ShotMode, double> defaultPrices = {
    ShotMode.single: 50.0,
    ShotMode.triple: 80.0,
    ShotMode.quad: 100.0,
    ShotMode.hex: 120.0,
  };

  PricingService(this._db);

  /// Get price for a specific [ShotMode]. Returns default price if not configured.
  Future<double> getPriceForMode(ShotMode mode) async {
    final prices = await _db.getAllPrices();
    final match = prices.where((p) => p.tierChar == mode.tierChar).firstOrNull;
    return match?.price ?? defaultPrices[mode] ?? 0.0;
  }

  /// Set price for a specific [ShotMode]. Also updates settings table for backwards compatibility.
  Future<void> setPriceForMode(ShotMode mode, double price) async {
    await _db.setPrice(mode.tierChar, price);
    await _db.setSetting('price_${mode.tierChar}', price.toStringAsFixed(2));
  }

  /// Saves prices for all given shot modes.
  Future<void> saveAllPrices(Map<ShotMode, double> prices) async {
    for (final entry in prices.entries) {
      await setPriceForMode(entry.key, entry.value);
    }
  }

  /// Returns all prices as a map of ShotMode → price.
  Future<Map<ShotMode, double>> getAllPrices() async {
    final prices = await _db.getAllPrices();
    return {
      for (final p in prices)
        ShotModeExtension.fromTierChar(p.tierChar): p.price,
    };
  }

  /// Returns all prices, falling back to default prices for unconfigured modes.
  Future<Map<ShotMode, double>> getResolvedPrices() async {
    final stored = await getAllPrices();
    return {
      for (final mode in ShotMode.values)
        mode: stored[mode] ?? defaultPrices[mode] ?? 0.0,
    };
  }
}
