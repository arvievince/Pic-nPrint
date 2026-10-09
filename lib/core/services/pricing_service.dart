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

  PricingService(this._db);

  /// Get price for a specific [ShotMode]. Returns 0.0 if not configured.
  Future<double> getPriceForMode(ShotMode mode) async {
    final prices = await _db.getAllPrices();
    final match = prices.where((p) => p.tierChar == mode.tierChar).firstOrNull;
    return match?.price ?? 0.0;
  }

  /// Set price for a specific [ShotMode].
  Future<void> setPriceForMode(ShotMode mode, double price) =>
      _db.setPrice(mode.tierChar, price);

  /// Returns all prices as a map of ShotMode → price.
  Future<Map<ShotMode, double>> getAllPrices() async {
    final prices = await _db.getAllPrices();
    return {
      for (final p in prices)
        ShotModeExtension.fromTierChar(p.tierChar): p.price,
    };
  }
}
