class OrderModel {
  final String id;
  final String userId;
  final String? customerName;
  final String? customerEmail;
  final String? customerPhone;
  final String? deliveryAddress;
  final String? paymentMethod;
  final String? paymentStatus;
  final String status; // Mapped from order_status
  final String? deliveryType;
  final String? notes;
  final String? gstNumber;
  final double totalAmount;
  final double subtotal;
  final double gstAmount;
  final double deliveryCharge;
  final bool invoiceRequired;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<OrderItemModel> items;
  final DateTime? estimatedDelivery;
  final Map<String, DateTime>? trackingMilestones;
  final String? statusNotes;
  final DateTime? deliveredAt;
  final DateTime? paymentDueDate;
  final String? paymentSource;
  final int? paymentDueDays;    // days granted by admin for payment window
  final String? transactionId;  // bank UTR/reference submitted by user after payment

  OrderModel({
    required this.id,
    required this.userId,
    this.customerName,
    this.customerEmail,
    this.customerPhone,
    this.deliveryAddress,
    this.paymentMethod,
    this.paymentStatus,
    required this.status,
    this.deliveryType,
    this.notes,
    this.gstNumber,
    required this.totalAmount,
    required this.subtotal,
    required this.gstAmount,
    required this.deliveryCharge,
    required this.invoiceRequired,
    required this.createdAt,
    this.updatedAt,
    required this.items,
    this.estimatedDelivery,
    this.trackingMilestones,
    this.statusNotes,
    this.deliveredAt,
    this.paymentDueDate,
    this.paymentSource,
    this.paymentDueDays,
    this.transactionId,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    // Parse tracking milestones if available
    Map<String, DateTime>? milestones;
    if (json['tracking_milestones'] != null) {
      final m = json['tracking_milestones'] as Map<String, dynamic>;
      milestones = m.map((key, value) => MapEntry(key, DateTime.parse(value)));
    }

    return OrderModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      customerName: json['customer_name'],
      customerEmail: json['customer_email'],
      customerPhone: json['customer_phone'],
      deliveryAddress: json['delivery_address'],
      paymentMethod: json['payment_method'],
      paymentStatus: json['payment_status'],
      status: json['order_status'] ?? json['status'] ?? 'pending',
      deliveryType: json['delivery_type'],
      notes: json['notes'],
      gstNumber: json['gst_number'],
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      gstAmount: (json['gst_amount'] as num?)?.toDouble() ?? 0.0,
      deliveryCharge: (json['delivery_charge'] as num?)?.toDouble() ?? 0.0,
      invoiceRequired: json['invoice_required'] ?? false,
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
      estimatedDelivery: json['estimated_delivery'] != null 
          ? DateTime.parse(json['estimated_delivery']) 
          : null,
      trackingMilestones: milestones,
      statusNotes: json['status_notes'],
      deliveredAt: json['delivered_at'] != null 
          ? DateTime.parse(json['delivered_at']) 
          : null,
      paymentDueDate: json['payment_due_date'] != null
          ? DateTime.parse(json['payment_due_date'])
          : null,
      paymentSource: json['payment_source'],
      paymentDueDays: (json['payment_due_days'] as num?)?.toInt(),
      transactionId: json['transaction_id'] as String?,
      items: json['items'] != null
          ? (json['items'] as List)
              .map((item) => OrderItemModel.fromJson(item))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'customer_name': customerName,
      'customer_email': customerEmail,
      'customer_phone': customerPhone,
      'delivery_address': deliveryAddress,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'order_status': status,
      'delivery_type': deliveryType,
      'notes': notes,
      'gst_number': gstNumber,
      'total_amount': totalAmount,
      'subtotal': subtotal,
      'gst_amount': gstAmount,
      'delivery_charge': deliveryCharge,
      'invoice_required': invoiceRequired,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'estimated_delivery': estimatedDelivery?.toIso8601String(),
      'tracking_milestones': trackingMilestones?.map((key, value) => MapEntry(key, value.toIso8601String())),
      'status_notes': statusNotes,
      'delivered_at': deliveredAt?.toIso8601String(),
      'payment_due_date': paymentDueDate?.toIso8601String(),
      'payment_source': paymentSource,
      'payment_due_days': paymentDueDays,
      'transaction_id': transactionId,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  // Helper to get tracking step index (0: confirmed, 1: transport, 2: delivered)
  int get trackingStepIndex {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'processing':
        return 0;
      case 'shipped':
      case 'in_transport':
      case 'transport':
        return 1;
      case 'delivered':
        return 2;
      case 'returned':
        return 3;
      default:
        return 0;
    }
  }
}

class OrderItemModel {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? qualityOptionId;
  final String qualityOptionName;
  final String? unit;
  final bool isReturnable;
  final String? imageUrl;

  OrderItemModel({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.qualityOptionId,
    required this.qualityOptionName,
    this.unit,
    this.isReturnable = true,
    this.imageUrl,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    // Handle quality option mapping from CartService structure
    String? qid = json['quality_option_id'];
    String qname = json['quality_option_name'] ?? '';
    
    if (json['quality_option'] != null) {
      final qo = json['quality_option'] as Map<String, dynamic>;
      qid ??= qo['id'];
      if (qname.isEmpty) qname = qo['name'] ?? '';
    }

    return OrderItemModel(
      productId: json['product_id'] ?? '',
      productName: json['product_name'] ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      qualityOptionId: qid,
      qualityOptionName: qname,
      unit: json['unit'],
      isReturnable: json['is_returnable'] as bool? ?? true,
      imageUrl: json['image_url'] ?? json['product_image'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'quality_option_id': qualityOptionId,
      'quality_option_name': qualityOptionName,
      'unit': unit,
      'is_returnable': isReturnable,
      'image_url': imageUrl,
    };
  }
}













