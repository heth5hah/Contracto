import 'package:flutter/foundation.dart';
import 'package:contracto_app/features/products/data/models/product_model.dart';

class QuoteRequestCartService extends ChangeNotifier {
  final Map<String, QuoteRequestItem> _items = {};

  Map<String, QuoteRequestItem> get items => Map.unmodifiable(_items);

  int get itemCount => _items.length;

  bool get isEmpty => _items.isEmpty;

  // Add product to quote request cart
  void addItem(ProductModel product,
      {double quantity = 1.0,
      String? qualityOptionId,
      String? qualityOptionName,
      String? notes,
      String? brandId,
      String? brandName,
      String? unit,
      String? unitName,
      bool replaceQuantity = false}) {
    final key = _generateKey(product, qualityOptionId, brandId, unit);

    if (_items.containsKey(key)) {
      _items[key] = _items[key]!.copyWith(
        quantity: replaceQuantity ? quantity : _items[key]!.quantity + quantity,
        notes: notes ?? _items[key]!.notes,
      );
    } else {
      _items[key] = QuoteRequestItem(
        product: product,
        quantity: quantity,
        qualityOptionId: qualityOptionId,
        qualityOptionName: qualityOptionName ?? product.productName,
        notes: notes,
        brandId: brandId,
        brandName: brandName,
        unit: unit ?? product.unit ?? 'Pcs',
        unitName: unitName ?? unit ?? product.unit ?? 'Piece',
      );
    }
    notifyListeners();
  }

  // Remove item from quote request cart
  void removeItem(String key) {
    _items.remove(key);
    notifyListeners();
  }

  // Update item quantity
  void updateQuantity(String key, double quantity) {
    if (_items.containsKey(key)) {
      if (quantity <= 0) {
        _items.remove(key);
      } else {
        _items[key] = _items[key]!.copyWith(quantity: quantity);
      }
      notifyListeners();
    }
  }

  // Update item unit
  void updateUnit(String key, String unit, String unitName) {
    if (_items.containsKey(key)) {
      _items[key] = _items[key]!.copyWith(unit: unit, unitName: unitName);
      notifyListeners();
    }
  }

  // Clear all items
  void clear() {
    _items.clear();
    notifyListeners();
  }

  // Get total number of items (sum of quantities)
  double get totalItems {
    return _items.values.fold(0.0, (sum, item) => sum + item.quantity);
  }

  // Generate unique key for each item (includes unit)
  String _generateKey(
      ProductModel product, String? qualityOptionId, String? brandId, String? unit) {
    String key = product.id;
    if (qualityOptionId != null) {
      key += '_$qualityOptionId';
    }
    if (brandId != null) {
      key += '_$brandId';
    }
    if (unit != null) {
      key += '_$unit';
    }
    return key;
  }

  // Get items as list for submission
  List<QuoteRequestItem> get itemsList => _items.values.toList();
}

class QuoteRequestItem {
  final ProductModel product;
  final double quantity; // Changed from int to double for decimal support
  final String? qualityOptionId;
  final String qualityOptionName;
  final String? notes;
  final String? brandId;
  final String? brandName;
  final String unit; // Unit code (e.g., "Kg", "Ton")
  final String unitName; // Unit display name (e.g., "Kilogram", "Ton")

  QuoteRequestItem({
    required this.product,
    required this.quantity,
    this.qualityOptionId,
    required this.qualityOptionName,
    this.notes,
    this.brandId,
    this.brandName,
    this.unit = 'Pcs',
    this.unitName = 'Piece',
  });

  /// Display string for quantity with unit (e.g., "2.5 Kg")
  String get quantityDisplay => '${quantity.toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 2)} $unit';

  QuoteRequestItem copyWith({
    ProductModel? product,
    double? quantity,
    String? qualityOptionId,
    String? qualityOptionName,
    String? notes,
    String? brandId,
    String? brandName,
    String? unit,
    String? unitName,
  }) {
    return QuoteRequestItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      qualityOptionId: qualityOptionId ?? this.qualityOptionId,
      qualityOptionName: qualityOptionName ?? this.qualityOptionName,
      notes: notes ?? this.notes,
      brandId: brandId ?? this.brandId,
      brandName: brandName ?? this.brandName,
      unit: unit ?? this.unit,
      unitName: unitName ?? this.unitName,
    );
  }
}

