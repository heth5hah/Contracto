import 'dart:convert';

class Order {
  final String id;
  final String? orderId;
  final String? customerName;
  final String? customerEmail;
  final String? customerPhone;
  final double? totalAmount;
  final String status;
  final String? statusNotes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? returnStatus; // 'No Return', 'Return Requested', 'Partial Return', 'Return Approved', 'Return Completed'
  final int? returnRequestCount; // Number of return requests for this order
  final bool? hasReturn; // Whether the order has any return requests
  final String? paymentStatus;
  final String? paymentId;
  final String? paymentMethod;
  final String? userId;
  final String? deliveryType;
  final String? transactionId;
  final String? paymentSource;
  final DateTime? paymentDueDate;

  final List<OrderItem>? items;

  Order({
    required this.id,
    this.orderId,
    this.customerName,
    this.customerEmail,
    this.customerPhone,
    this.totalAmount,
    required this.status,
    this.statusNotes,
    required this.createdAt,
    this.updatedAt,
    this.returnStatus,
    this.returnRequestCount,
    this.hasReturn,
    this.paymentStatus,
    this.paymentId,
    this.paymentMethod,
    this.userId,
    this.deliveryType,
    this.transactionId,
    this.paymentSource,
    this.paymentDueDate,
    this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    var itemsList = <OrderItem>[];
    
    // Attempt to find items in various possible locations
    final itemsFromTable = json['order_items'];
    final itemsFromJson = json['items'];
    final quoteItemsFromTable = json['quote_items'];
    
    if (itemsFromTable is List && itemsFromTable.isNotEmpty) {
      itemsList = itemsFromTable
          .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
          .toList();
    } else if (itemsFromJson is List && itemsFromJson.isNotEmpty) {
      itemsList = itemsFromJson
          .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
          .toList();
    } else if (quoteItemsFromTable is List && quoteItemsFromTable.isNotEmpty) {
      itemsList = quoteItemsFromTable
          .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
          .toList();
    }
    
    // If it's a JSON string (sometimes happen with some Supabase configurations)
    if (itemsList.isEmpty && itemsFromJson is String && itemsFromJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(itemsFromJson);
        if (decoded is List) {
          itemsList = decoded
              .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        print('DEBUG: Error decoding items JSON string: $e');
      }
    }

    // Calculate return status from returns table (will be populated by provider)
    return Order(
      id: json['id'],
      orderId: json['order_id'],
      customerName: json['customer_name'],
      customerEmail: json['customer_email'],
      customerPhone: json['customer_phone'],
      totalAmount: (json['total_amount'] as num?)?.toDouble(),
      status: json['status'] ?? json['order_status'] ?? 'pending',
      statusNotes: json['status_notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      returnStatus: json['return_status'], // Will be set by provider
      returnRequestCount: json['return_request_count'] != null ? (json['return_request_count'] as num).toInt() : null,
      hasReturn: json['has_return'] as bool? ?? false,
      paymentStatus: json['payment_status'],
      paymentMethod: json['payment_method'] as String?,
      userId: json['user_id'] as String?,
      deliveryType: json['delivery_type'],
      items: itemsList,
      paymentId: _parsePaymentId(json['notes']),
      transactionId: json['transaction_id'] as String?,
      paymentSource: json['payment_source'] as String?,
      paymentDueDate: json['payment_due_date'] != null ? DateTime.parse(json['payment_due_date']) : null,
    );
  }

  static String? _parsePaymentId(String? notes) {
    if (notes == null) return null;
    try {
      if (notes.contains('Payment ID: ')) {
        final parts = notes.split('Payment ID: ');
        if (parts.length > 1) {
          return parts[1].trim().split(' ').first.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
        }
      }
    } catch (_) {}
    return null;
  }

}

class OrderItem {
  final String id;
  final String orderId;
  final String? productId;
  final double quantity;
  final double unitPrice;
  final double totalPrice;
  final String? productName;
  final String? productImage;
  final String? sku;
  final String? category;
  final String? unit;
  final bool? isReturnable;

  OrderItem({
    required this.id,
    required this.orderId,
    this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.productName,
    this.productImage,
    this.sku,
    this.category,
    this.unit,
    this.isReturnable,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    // Handle joined product data if available
    String? name;
    String? image;
    String? sku;
    String? category;
    String? unit;
    
    if (json['products'] != null) {
      final product = json['products'];
      name = product['product_name'] ?? product['name'];
      image = product['image_url'] ?? product['image'];
      sku = product['product_id']; // This is often used as SKU in the UI
      category = product['category'];
      unit = product['unit'];
    }

    // Map fields from both order_items table and mobile app's JSON column
    return OrderItem(
      id: (json['id'] ?? '').toString(),
      orderId: (json['order_id'] ?? json['quote_id'] ?? json['quote_request_id'] ?? '').toString(),
      productId: json['product_id'],
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unitPrice: (json['unit_price'] ?? json['price'] ?? 0.0).toDouble(),
      totalPrice: (json['total_price'] ?? json['total'] ?? 0.0).toDouble(),
      productName: name ?? json['product_name'] ?? json['name'],
      productImage: image ?? json['product_image'] ?? json['image_url'] ?? json['image'],
      sku: sku ?? json['sku'] ?? json['product_id'],
      category: category ?? json['category'],
      unit: unit ?? json['unit'],
      isReturnable: json['is_returnable'] as bool?,
    );
  }
}
