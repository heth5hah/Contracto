class ReturnModel {
  final String id;
  final String orderId;
  final String userId;
  final String returnStatus;
  final String? returnReason;
  final String? description;
  final String? notes;
  final double refundAmount;
  final double refundAmountFinal;
  final int pickupDays;
  final bool bankDetailsSubmitted;
  final String? rejectionReason;
  final String? refundTransactionId;
  final DateTime? refundProcessedAt;
  final List<ReturnItemModel> items;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? pickupDate;

  ReturnModel({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.returnStatus,
    this.returnReason,
    this.description,
    this.notes,
    required this.refundAmount,
    this.refundAmountFinal = 0,
    this.pickupDays = 3,
    this.bankDetailsSubmitted = false,
    this.rejectionReason,
    this.refundTransactionId,
    this.refundProcessedAt,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
    this.pickupDate,
  });

  factory ReturnModel.fromJson(Map<String, dynamic> json) {
    return ReturnModel(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      userId: json['user_id'] as String,
      returnStatus: json['return_status'] as String? ?? 'pending',
      returnReason: json['return_reason'] as String?,
      description: json['description'] as String?,
      notes: json['notes'] as String?,
      refundAmount: (json['refund_amount'] as num?)?.toDouble() ?? 0.0,
      refundAmountFinal: (json['refund_amount_final'] as num?)?.toDouble() ?? 0.0,
      pickupDays: (json['pickup_days'] as int?) ?? 3,
      bankDetailsSubmitted: json['bank_details_submitted'] as bool? ?? false,
      rejectionReason: json['rejection_reason'] as String?,
      refundTransactionId: json['refund_transaction_id'] as String?,
      refundProcessedAt: json['refund_processed_at'] != null
          ? DateTime.parse(json['refund_processed_at'] as String)
          : null,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => ReturnItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      pickupDate: json['pickup_date'] != null
          ? DateTime.parse(json['pickup_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'user_id': userId,
      'return_status': returnStatus,
      'return_reason': returnReason,
      'description': description,
      'notes': notes,
      'refund_amount': refundAmount,
      'refund_amount_final': refundAmountFinal,
      'pickup_days': pickupDays,
      'bank_details_submitted': bankDetailsSubmitted,
      'rejection_reason': rejectionReason,
      'refund_transaction_id': refundTransactionId,
      'refund_processed_at': refundProcessedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'pickup_date': pickupDate?.toIso8601String(),
    };
  }

  /// Human-readable status text
  String get statusText {
    switch (returnStatus) {
      case 'pending':       return 'Pending Review';
      case 'approved':      return 'Approved';
      case 'rejected':      return 'Rejected';
      case 'pickup_scheduled': return 'Pickup Scheduled';
      case 'picked_up':    return 'Picked Up';
      case 'product_received': return 'Product Received';
      case 'refund_pending': return 'Refund Pending';
      case 'refund_completed': return 'Refund Completed';
      case 'cancelled':     return 'Cancelled';
      case 'completed':     return 'Completed';
      default:              return returnStatus;
    }
  }

  /// Step index for timeline (0-based)
  int get timelineStep {
    switch (returnStatus) {
      case 'pending':          return 0;
      case 'approved':         return 1;
      case 'pickup_scheduled': return 2;
      case 'picked_up':        return 3;
      case 'product_received':
      case 'refund_pending':   return 4;
      case 'refund_completed':
      case 'completed':        return 5;
      default:                 return 0;
    }
  }

  bool get isActive => returnStatus != 'rejected' && returnStatus != 'cancelled';
  bool get isCompleted => returnStatus == 'refund_completed' || returnStatus == 'completed';
  bool get isRejected => returnStatus == 'rejected' || returnStatus == 'cancelled';
  bool get awaitingBankDetails =>
      returnStatus == 'approved' && !bankDetailsSubmitted;
}

class ReturnItemModel {
  final String id;
  final String returnId;
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? qualityOptionName;
  final String? unit;
  final DateTime createdAt;

  ReturnItemModel({
    required this.id,
    required this.returnId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.qualityOptionName,
    this.unit,
    required this.createdAt,
  });

  factory ReturnItemModel.fromJson(Map<String, dynamic> json) {
    return ReturnItemModel(
      id: json['id'] as String? ?? '',
      returnId: json['return_id'] as String? ?? '',
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      quantity: json['quantity'] as int,
      unitPrice: (json['unit_price'] as num).toDouble(),
      totalPrice: (json['total_price'] as num).toDouble(),
      qualityOptionName: json['quality_option_name'] as String?,
      unit: json['unit'] as String?,
      createdAt: DateTime.parse(
          json['created_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'return_id': returnId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'quality_option_name': qualityOptionName,
      'unit': unit,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get displayName {
    if (qualityOptionName != null && qualityOptionName!.isNotEmpty) {
      return '$productName ($qualityOptionName)';
    }
    return productName;
  }
}

/// Bank details model
class ReturnBankDetails {
  final String id;
  final String returnId;
  final String accountHolderName;
  final String bankName;
  final String accountNumber;
  final String ifscCode;
  final String? upiId;
  final DateTime createdAt;

  ReturnBankDetails({
    required this.id,
    required this.returnId,
    required this.accountHolderName,
    required this.bankName,
    required this.accountNumber,
    required this.ifscCode,
    this.upiId,
    required this.createdAt,
  });

  factory ReturnBankDetails.fromJson(Map<String, dynamic> json) {
    return ReturnBankDetails(
      id: json['id'] as String,
      returnId: json['return_id'] as String,
      accountHolderName: json['account_holder_name'] as String,
      bankName: json['bank_name'] as String,
      accountNumber: json['account_number'] as String,
      ifscCode: json['ifsc_code'] as String,
      upiId: json['upi_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Masked account number for display: XXXXXX1234
  String get maskedAccountNumber {
    if (accountNumber.length <= 4) return accountNumber;
    final last4 = accountNumber.substring(accountNumber.length - 4);
    final masked = 'X' * (accountNumber.length - 4);
    return masked + last4;
  }
}
