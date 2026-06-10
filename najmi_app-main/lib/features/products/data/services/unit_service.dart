import 'package:contracto_app/core/network/supabase_service.dart';

class UnitModel {
  final String id;
  final String name;
  final String code;
  final String? symbol;
  final bool isActive;
  final int sortOrder;

  UnitModel({
    required this.id,
    required this.name,
    required this.code,
    this.symbol,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory UnitModel.fromJson(Map<String, dynamic> json) {
    return UnitModel(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      symbol: json['symbol'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'symbol': symbol,
      'is_active': isActive,
      'sort_order': sortOrder,
    };
  }

  /// Display string for UI (e.g., "Kilogram (Kg)")
  String get displayName => '$name ($code)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UnitModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class UnitService {
  // Singleton pattern
  static final UnitService _instance = UnitService._internal();
  factory UnitService() => _instance;
  UnitService._internal();

  // Cache for units
  List<UnitModel>? _cachedUnits;
  DateTime? _lastFetchTime;
  static const _cacheDuration = Duration(minutes: 10);

  /// Get all active units
  Future<List<UnitModel>> getUnits({bool forceRefresh = false}) async {
    // Return cached data if valid
    if (!forceRefresh && _cachedUnits != null && _lastFetchTime != null) {
      final timeSinceLastFetch = DateTime.now().difference(_lastFetchTime!);
      if (timeSinceLastFetch < _cacheDuration) {
        return _cachedUnits!;
      }
    }

    try {
      final response = await SupabaseService.client
          .from('units')
          .select('*')
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      _cachedUnits = (response as List)
          .map((json) => UnitModel.fromJson(json as Map<String, dynamic>))
          .toList();
      _lastFetchTime = DateTime.now();

      return _cachedUnits!;
    } catch (e) {
      print('Error fetching units: $e');
      // Return cached data if available, even if expired
      if (_cachedUnits != null) {
        return _cachedUnits!;
      }
      // Return default units as fallback
      return _getDefaultUnits();
    }
  }

  /// Get units for a specific product
  Future<List<UnitModel>> getUnitsForProduct(String productId) async {
    try {
      final response = await SupabaseService.client
          .from('product_units')
          .select('unit_id, is_default, units(*)')
          .eq('product_id', productId);

      if ((response as List).isEmpty) {
        // Return all active units if no specific units assigned
        return getUnits();
      }

      final units = (response as List).map((json) {
        final unitData = json['units'] as Map<String, dynamic>;
        return UnitModel.fromJson(unitData);
      }).toList();

      // Sort by sort_order
      units.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return units;
    } catch (e) {
      print('Error fetching units for product: $e');
      return getUnits();
    }
  }

  /// Get default unit for a product
  Future<UnitModel?> getDefaultUnitForProduct(String productId) async {
    try {
      final response = await SupabaseService.client
          .from('product_units')
          .select('units(*)')
          .eq('product_id', productId)
          .eq('is_default', true)
          .maybeSingle();

      if (response != null && response['units'] != null) {
        return UnitModel.fromJson(response['units'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error fetching default unit for product: $e');
      return null;
    }
  }

  /// Get unit by code (e.g., "Kg")
  Future<UnitModel?> getUnitByCode(String code) async {
    final units = await getUnits();
    try {
      return units.firstWhere(
        (u) => u.code.toLowerCase() == code.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Clear cache
  void clearCache() {
    _cachedUnits = null;
    _lastFetchTime = null;
  }

  /// Default units fallback (for offline or error scenarios)
  List<UnitModel> _getDefaultUnits() {
    return [
      UnitModel(id: 'default-pcs', name: 'Piece', code: 'Pcs', symbol: 'pcs', sortOrder: 1),
      UnitModel(id: 'default-kg', name: 'Kilogram', code: 'Kg', symbol: 'kg', sortOrder: 2),
      UnitModel(id: 'default-ton', name: 'Ton', code: 'Ton', symbol: 't', sortOrder: 3),
      UnitModel(id: 'default-bag', name: 'Bag', code: 'Bag', symbol: 'bag', sortOrder: 4),
      UnitModel(id: 'default-brass', name: 'Brass', code: 'Brass', symbol: 'brass', sortOrder: 5),
      UnitModel(id: 'default-cbm', name: 'Cubic Meter', code: 'CBM', symbol: 'm³', sortOrder: 6),
      UnitModel(id: 'default-ltr', name: 'Liter', code: 'Ltr', symbol: 'L', sortOrder: 7),
      UnitModel(id: 'default-ft', name: 'Feet', code: 'Ft', symbol: 'ft', sortOrder: 8),
      UnitModel(id: 'default-mtr', name: 'Meter', code: 'Mtr', symbol: 'm', sortOrder: 9),
      UnitModel(id: 'default-qtl', name: 'Quintal', code: 'Qtl', symbol: 'qtl', sortOrder: 10),
      UnitModel(id: 'default-bdl', name: 'Bundle', code: 'Bdl', symbol: 'bdl', sortOrder: 11),
      UnitModel(id: 'default-nos', name: 'Number', code: 'Nos', symbol: 'nos', sortOrder: 12),
    ];
  }
}
