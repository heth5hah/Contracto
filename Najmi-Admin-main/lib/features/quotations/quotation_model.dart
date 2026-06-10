class Quotation {
  final String id;
  final String? userId;
  final String? customerName;
  final String? customerEmail;
  final String? customerPhone;
  final String? deliveryAddress;
  final String? notes;
  final List<QuotationItem> items;
  final double totalAmount;
  final double transportCharges;
  final double taxAmount;
  final DateTime createdAt;
  final String status;
  final String adminStatus; // 'new', 'processing', 'closed'
  final int validityDays; // delivery / validity days set by admin
  final bool isReturnable; // admin can mark quote items as non-returnable
  final String? paymentMethod;
  final String? transactionId;

  final List<QuotationItem>? quotedItems;

  Quotation({
    required this.id,
    this.userId,
    this.customerName,
    this.customerEmail,
    this.customerPhone,
    this.deliveryAddress,
    this.notes,
    required this.items,
    required this.totalAmount,
    this.transportCharges = 0.0,
    this.taxAmount = 0.0,
    required this.createdAt,
    required this.status,
    this.adminStatus = 'new',
    this.validityDays = 7,
    this.isReturnable = true,
    this.quotedItems,
    this.paymentMethod,
    this.transactionId,
  });

  factory Quotation.fromJson(Map<String, dynamic> json) {
    print('DEBUG: Parsing Quotation ID: ${json['id']}');
    final itemsList = json['quote_request_items'] as List?;
    print('DEBUG: quote_request_items count: ${itemsList?.length ?? 0}');

    // Parse priced items from the 'quotes' join if available
    List<QuotationItem>? prices;
    final quotes = json['quotes'] as List?;
    print('DEBUG: quotes join count: ${quotes?.length ?? 0}');

    int parsedValidityDays = 7;
    bool parsedIsReturnable = true;
    if (quotes != null && quotes.isNotEmpty) {
      final latestQuote = quotes.first;
      prices = (latestQuote['quote_items'] as List?)
          ?.map((i) => QuotationItem.fromJson(i))
          .toList();
      parsedValidityDays = (latestQuote['validity_days'] as int?) ?? 7;
      parsedIsReturnable = (latestQuote['is_returnable'] as bool?) ?? true;
      print('DEBUG: Parsed priced items: ${prices?.length ?? 0}');
    }

    // Extract user information
    final userData = json['users'];
    final userEmail = userData?['email'] ?? json['customer_email'];
    final customerName =
        json['customer_name'] ??
        userData?['name'] ??
        (userEmail != null ? userEmail.split('@')[0] : null) ??
        json['product_name'] ??
        (itemsList != null && itemsList.isNotEmpty
            ? (itemsList.first['quality_option_name'] ??
                  itemsList.first['product_name'] ??
                  itemsList.first['item_name'])
            : null);
    final customerPhone = json['customer_phone'] ?? userData?['mobile'];
    final deliveryAddress = json['delivery_address'];

    return Quotation(
      id: json['id'],
      userId: json['user_id']?.toString(),
      customerName: customerName,
      customerEmail: userEmail,
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      notes: json['notes'],
      items: itemsList?.map((i) => QuotationItem.fromJson(i)).toList() ?? [],
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      transportCharges: (json['transport_charges'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['created_at']),
      status: json['status'] ?? 'pending',
      adminStatus: json['admin_status'] ?? 'new',
      validityDays: parsedValidityDays,
      isReturnable: parsedIsReturnable,
      quotedItems: prices,
      paymentMethod: json['payment_method']?.toString(),
      transactionId: json['transaction_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transport_charges': transportCharges,
      'admin_status': adminStatus,
      'is_returnable': isReturnable,
    };
  }
}

class QuotationItem {
  final String productName;
  final double quantity;
  final double price;
  final String? unit;
  final String? brandId;
  final String? brandName;
  final String? qualityOptionName;
  final String? notes;
  final String? productId;
  final String? productDescription;
  final double? gstPercent; // GST % stored on the product
  final bool isAvailable;

  QuotationItem({
    required this.productName,
    required this.quantity,
    required this.price,
    this.unit,
    this.brandId,
    this.brandName,
    this.qualityOptionName,
    this.notes,
    this.productId,
    this.productDescription,
    this.gstPercent,
    this.isAvailable = true,
  });

  factory QuotationItem.fromJson(Map<String, dynamic> json) {
    // Helper to extract data from potential List or Map
    dynamic getSafe(dynamic data) {
      if (data == null) return null;
      if (data is List) return data.isNotEmpty ? data.first : null;
      return data;
    }

    final productsData = getSafe(json['products']);
    final brandsData =
        getSafe(json['brands']) ?? getSafe(productsData?['brands']);

    String? brand;
    if (brandsData != null) {
      brand = brandsData['name']?.toString();
    }

    String? desc;
    String? productNameFromProducts;
    double? gstPercent;
    if (productsData != null) {
      desc = productsData['description']?.toString();
      productNameFromProducts = productsData['name']?.toString();
      gstPercent = (productsData['gst_percent'] as num?)?.toDouble();
    }

    // Priority order for product name:
    // 1. product_name field (directly from quote_request_items)
    // 2. quality_option_name (the specific variant)
    // 3. name from products join
    // 4. item_name fallback
    final productName =
        json['product_name']?.toString() ??
        json['quality_option_name']?.toString() ??
        productNameFromProducts ??
        json['item_name']?.toString() ??
        json['name']?.toString() ??
        json['product_id']?.toString() ??
        json['item_id']?.toString() ??
        'Unknown Product';

    // For brand, try multiple sources
    final brandName =
        brand ?? json['brand_name']?.toString() ?? json['brand']?.toString();

    return QuotationItem(
      productName: productName,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      price:
          (json['unit_price'] as num?)?.toDouble() ??
          (json['price'] as num?)?.toDouble() ??
          0.0,
      unit: json['unit']?.toString(),
      brandId: json['brand_id']?.toString(),
      brandName: brandName,
      qualityOptionName: json['quality_option_name']?.toString(),
      notes: json['notes']?.toString(),
      productId: json['product_id']?.toString(),
      productDescription: desc,
      gstPercent: gstPercent,
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }
}
