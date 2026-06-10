import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class ReturnRequest {
  final String id;
  final String orderId;
  final String userId;
  final String returnStatus;
  final String? returnReason;
  final String? notes;
  final String? description;
  final double refundAmount;
  final double refundAmountFinal;
  final int pickupDays;
  final DateTime? pickupDate;
  final bool bankDetailsSubmitted;
  final String? rejectionReason;
  final String? refundTransactionId;
  final DateTime? refundProcessedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ReturnItem> items;
  final String? customerName;
  final String? customerEmail;
  final String? orderNumber;

  const ReturnRequest({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.returnStatus,
    this.returnReason,
    this.notes,
    this.description,
    required this.refundAmount,
    this.refundAmountFinal = 0,
    this.pickupDays = 3,
    this.pickupDate,
    this.bankDetailsSubmitted = false,
    this.rejectionReason,
    this.refundTransactionId,
    this.refundProcessedAt,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
    this.customerName,
    this.customerEmail,
    this.orderNumber,
  });

  factory ReturnRequest.fromJson(Map<String, dynamic> json, {List<ReturnItem>? items}) {
    return ReturnRequest(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      userId: json['user_id'] as String,
      returnStatus: json['return_status'] as String? ?? 'pending',
      returnReason: json['return_reason'] as String?,
      notes: json['notes'] as String?,
      description: json['description'] as String?,
      refundAmount: (json['refund_amount'] as num?)?.toDouble() ?? 0.0,
      refundAmountFinal: (json['refund_amount_final'] as num?)?.toDouble() ?? 0.0,
      pickupDays: (json['pickup_days'] as int?) ?? 3,
      pickupDate: json['pickup_date'] != null ? DateTime.parse(json['pickup_date'] as String) : null,
      bankDetailsSubmitted: json['bank_details_submitted'] as bool? ?? false,
      rejectionReason: json['rejection_reason'] as String?,
      refundTransactionId: json['refund_transaction_id'] as String?,
      refundProcessedAt: json['refund_processed_at'] != null
          ? DateTime.parse(json['refund_processed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      items: items ?? [],
      customerName: json['orders']?['customer_name'] as String?,
      customerEmail: json['orders']?['customer_email'] as String?,
      orderNumber: json['order_id']?.toString().substring(0, 8).toUpperCase(),
    );
  }

  String get statusText {
    switch (returnStatus) {
      case 'pending':          return 'Pending Review';
      case 'approved':         return 'Approved';
      case 'rejected':         return 'Rejected';
      case 'pickup_scheduled': return 'Pickup Scheduled';
      case 'picked_up':        return 'Picked Up';
      case 'product_received': return 'Product Received';
      case 'refund_pending':   return 'Refund Pending';
      case 'refund_completed': return 'Refund Completed';
      case 'completed':        return 'Completed';
      case 'cancelled':        return 'Cancelled';
      default:                 return returnStatus;
    }
  }
}

class ReturnItem {
  final String id;
  final String returnId;
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double totalPrice;
  final String? qualityOptionName;
  final String? unit;

  const ReturnItem({
    required this.id,
    required this.returnId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.qualityOptionName,
    this.unit,
  });

  factory ReturnItem.fromJson(Map<String, dynamic> json) {
    return ReturnItem(
      id: json['id'] as String,
      returnId: json['return_id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      totalPrice: (json['total_price'] as num).toDouble(),
      qualityOptionName: json['quality_option_name'] as String?,
      unit: json['unit'] as String?,
    );
  }
}

class ReturnBankDetails {
  final String accountHolderName;
  final String bankName;
  final String accountNumber;
  final String ifscCode;
  final String? upiId;

  const ReturnBankDetails({
    required this.accountHolderName,
    required this.bankName,
    required this.accountNumber,
    required this.ifscCode,
    this.upiId,
  });

  factory ReturnBankDetails.fromJson(Map<String, dynamic> json) {
    return ReturnBankDetails(
      accountHolderName: json['account_holder_name'] as String,
      bankName: json['bank_name'] as String,
      accountNumber: json['account_number'] as String,
      ifscCode: json['ifsc_code'] as String,
      upiId: json['upi_id'] as String?,
    );
  }

  String get maskedAccountNumber {
    if (accountNumber.length <= 4) return accountNumber;
    final last4 = accountNumber.substring(accountNumber.length - 4);
    return '${'X' * (accountNumber.length - 4)}$last4';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

final returnsProvider = FutureProvider<List<ReturnRequest>>((ref) async {
  final supabase = ref.watch(supabaseProvider);

  try {
    // ─── Self-healing: auto-create missing return records ─────────────
    // Find orders that are marked as returned/has_return but have no
    // matching record in the returns table. This handles cases where the
    // admin changed the order status dropdown or the mobile app INSERT
    // was blocked by RLS.
    try {
      final orphanedOrders = await supabase
          .from('orders')
          .select('id, user_id, total_amount, customer_name')
          .or('order_status.eq.returned,has_return.eq.true');

      for (var order in orphanedOrders) {
        final orderId = order['id'] as String;
        
        // Check if a return record exists for this order
        final existingReturn = await supabase
            .from('returns')
            .select('id')
            .eq('order_id', orderId)
            .maybeSingle();
        
        if (existingReturn == null) {
          // Auto-create the missing return record
          await supabase.from('returns').insert({
            'order_id': orderId,
            'user_id': order['user_id'],
            'return_status': 'pending',
            'return_reason': 'Return request',
            'refund_amount': order['total_amount'] ?? 0,
            'description': 'Auto-created for order marked as returned',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
          print('✅ Auto-created missing return record for order $orderId (${order['customer_name']})');
        }
      }
    } catch (e) {
      print('⚠️ Self-heal check skipped: $e');
      // Don't block the main fetch if self-heal fails
    }

    // ─── Fetch all returns normally ──────────────────────────────────
    final response = await supabase
        .from('returns')
        .select('*, orders(customer_name, customer_email)')
        .order('created_at', ascending: false);

    final returns = <ReturnRequest>[];
    for (var returnData in response) {
      final itemsResponse = await supabase
          .from('return_items')
          .select()
          .eq('return_id', returnData['id']);

      final items = (itemsResponse as List).map((item) => ReturnItem.fromJson(item)).toList();
      returns.add(ReturnRequest.fromJson(returnData, items: items));
    }
    return returns;
  } catch (e) {
    print('Error fetching returns: $e');
    return [];
  }
});

final returnBankDetailsProvider = FutureProvider.family<ReturnBankDetails?, String>((ref, returnId) async {
  final supabase = ref.watch(supabaseProvider);
  try {
    final response = await supabase
        .from('return_bank_details')
        .select()
        .eq('return_id', returnId)
        .maybeSingle();
    if (response == null) return null;
    return ReturnBankDetails.fromJson(response);
  } catch (e) {
    return null;
  }
});

final returnsManagementProvider = Provider((ref) => ReturnsManagementService(ref));

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class ReturnsManagementService {
  final Ref ref;
  ReturnsManagementService(this.ref);

  Future<bool> updateReturnStatus(String returnId, String newStatus,
      {Map<String, dynamic>? extra}) async {
    final supabase = ref.read(supabaseProvider);
    try {
      await supabase.from('returns').update({
        'return_status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
        if (extra != null) ...extra,
      }).eq('id', returnId);

      // Transition the overall order to 'returned' if refund is completed or return is fully completed
      if (newStatus == 'refund_completed' || newStatus == 'completed') {
        final returnData = await supabase.from('returns').select('order_id').eq('id', returnId).maybeSingle();
        if (returnData != null && returnData['order_id'] != null) {
          await supabase.from('orders').update({
            'order_status': 'returned',
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', returnData['order_id']);
        }
      }

      ref.invalidate(returnsProvider);
      return true;
    } catch (e) {
      print('Error updating return status: $e');
      return false;
    }
  }

  Future<bool> approveReturn(String returnId, int pickupDays) async {
    return updateReturnStatus(returnId, 'approved', extra: {'pickup_days': pickupDays});
  }

  Future<bool> rejectReturn(String returnId, String reason) async {
    return updateReturnStatus(returnId, 'rejected', extra: {'rejection_reason': reason});
  }

  Future<bool> setPickupDate(String returnId, DateTime date) async {
    return updateReturnStatus(returnId, 'pickup_scheduled', extra: {
      'pickup_date': date.toIso8601String().substring(0, 10),
    });
  }

  Future<bool> markPickedUp(String returnId) async {
    return updateReturnStatus(returnId, 'picked_up');
  }

  Future<bool> markProductReceived(String returnId) async {
    return updateReturnStatus(returnId, 'refund_pending');
  }

  Future<bool> processRefund(String returnId, double amount, String transactionId) async {
    final supabase = ref.read(supabaseProvider);
    try {
      // Find the user_id for this return
      final returnData = await supabase.from('returns').select('user_id').eq('id', returnId).maybeSingle();
      if (returnData != null && returnData['user_id'] != null) {
        final userId = returnData['user_id'];
        
        // Find their wallet / credit account
        final creditAccount = await supabase
            .from('business_credit_accounts')
            .select('*')
            .eq('user_id', userId)
            .maybeSingle();
            
        if (creditAccount != null) {
          final accountId = creditAccount['id'];
          
          await supabase.from('credit_usage').insert({
            'credit_account_id': accountId,
            'transaction_type': 'credit',
            'amount': amount,
            'description': 'Refund for return #$returnId',
            'balance_after': 0,
          });

          await supabase.rpc('recount_business_credit_balances', params: {
            'p_account_id': accountId,
          });
        } else {
          // Create a wallet for the user if they don't have one
          final newAccount = await supabase.from('business_credit_accounts').insert({
            'user_id': userId,
            'credit_limit': 0, // 0 limit for individual wallet
            'available_credit': amount,
            'used_credit': 0, // No negative used_credit
            'status': 'active',
          }).select().single();
          
          await supabase.from('credit_usage').insert({
            'credit_account_id': newAccount['id'],
            'transaction_type': 'credit',
            'amount': amount,
            'description': 'Refund for return #$returnId',
            'balance_after': amount,
          });

          await supabase.rpc('recount_business_credit_balances', params: {
            'p_account_id': newAccount['id'],
          });
        }
      }
    } catch (e) {
      print('Error crediting wallet for refund: $e');
      return false; // Prevent status update if wallet credit fails
    }

    return updateReturnStatus(returnId, 'refund_completed', extra: {
      'refund_amount_final': amount,
      'refund_transaction_id': transactionId,
      'refund_processed_at': DateTime.now().toIso8601String(),
    });
  }

  Future<bool> cancelReturn(String returnId) async {
    return updateReturnStatus(returnId, 'cancelled');
  }

  /// Fetch bank details directly (bypassing provider cache) for admin view
  Future<ReturnBankDetails?> getBankDetailsDirect(String returnId) async {
    final supabase = ref.read(supabaseProvider);
    try {
      final response = await supabase
          .from('return_bank_details')
          .select()
          .eq('return_id', returnId)
          .maybeSingle();
      if (response == null) return null;
      return ReturnBankDetails.fromJson(response);
    } catch (e) {
      print('Error fetching bank details: $e');
      return null;
    }
  }
}
