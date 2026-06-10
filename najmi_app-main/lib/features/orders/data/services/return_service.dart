import 'package:contracto_app/core/network/supabase_service.dart';
import 'package:contracto_app/features/orders/data/models/return_model.dart';
import 'package:contracto_app/features/orders/data/models/order_model.dart';

/// Model for return policy settings from admin panel
class ReturnPolicySettings {
  final bool returnsEnabled;
  final int returnWindowDays;

  const ReturnPolicySettings({
    this.returnsEnabled = true,
    this.returnWindowDays = 7,
  });

  factory ReturnPolicySettings.fromJson(Map<String, dynamic> json) {
    return ReturnPolicySettings(
      returnsEnabled: json['returns_enabled'] ?? true,
      returnWindowDays: json['return_window_days'] ?? 7,
    );
  }
}

class ReturnService {
  final _supabase = SupabaseService.client;

  /// Cache for return policy settings
  ReturnPolicySettings? _cachedPolicy;
  DateTime? _policyFetchedAt;

  /// Get return policy settings from admin configuration
  Future<ReturnPolicySettings> getReturnPolicySettings() async {
    // Use cache if fetched within last 5 minutes
    if (_cachedPolicy != null && 
        _policyFetchedAt != null && 
        DateTime.now().difference(_policyFetchedAt!).inMinutes < 5) {
      return _cachedPolicy!;
    }

    try {
      final response = await _supabase
          .from('settings')
          .select('value')
          .eq('key', 'return_policy')
          .maybeSingle();

      if (response != null && response['value'] != null) {
        _cachedPolicy = ReturnPolicySettings.fromJson(response['value'] as Map<String, dynamic>);
      } else {
        _cachedPolicy = const ReturnPolicySettings();
      }
      _policyFetchedAt = DateTime.now();
      return _cachedPolicy!;
    } catch (e) {
      print('Error fetching return policy: $e');
      return const ReturnPolicySettings();
    }
  }

  /// Get remaining days for return eligibility
  /// Returns -1 if returns are disabled or order not delivered
  /// Returns 0 if expired
  /// Returns positive number for remaining days
  Future<int> getRemainingReturnDays(OrderModel order) async {
    if (order.status != 'delivered' || order.deliveredAt == null) {
      return -1;
    }

    final policy = await getReturnPolicySettings();
    if (!policy.returnsEnabled) {
      return -1;
    }

    final now = DateTime.now().toUtc();
    final deliveredAtUtc = order.deliveredAt!.toUtc();
    final expiryDate = deliveredAtUtc.add(Duration(days: policy.returnWindowDays));
    if (now.isAfter(expiryDate)) return 0;
    
    final remaining = expiryDate.difference(now).inDays;
    return remaining < 0 ? 0 : remaining + 1; // +1 because partial days should count as 1 remaining day
  }

  /// Get the return policy expiry message
  Future<String> getReturnExpiryMessage() async {
    final policy = await getReturnPolicySettings();
    return 'Return period has expired. Returns are allowed within ${policy.returnWindowDays} days from delivery.';
  }

  /// Check if an order is eligible for return
  /// Returns true if order is delivered and within return window
  Future<bool> canReturnOrder(OrderModel order) async {
    // Must be delivered
    if (order.status != 'delivered') return false;

    // Must have delivery date
    if (order.deliveredAt == null) return false;

    // Get policy settings
    final policy = await getReturnPolicySettings();
    
    // Check if returns are enabled
    if (!policy.returnsEnabled) return false;

    // Check if within return window (UTC-safe)
    final now = DateTime.now().toUtc();
    final expiryDate = order.deliveredAt!.toUtc().add(Duration(days: policy.returnWindowDays));
    if (now.isAfter(expiryDate)) return false;

    // Check if all items already fully returned
    final returnableItems = await getReturnableItems(order);
    if (returnableItems.isEmpty) return false;

    return true;
  }

  /// Get items that can still be returned (not fully returned yet)
  Future<List<ReturnableItem>> getReturnableItems(OrderModel order) async {
    // Get all existing returns for this order
    final returnsData = await _supabase
        .from('returns')
        .select()
        .eq('order_id', order.id)
        .inFilter('return_status', ['pending', 'approved', 'completed']);

    // Get all return items from those returns
    final Map<String, int> returnedQuantities = {};
    
    for (var returnData in returnsData) {
      final returnId = returnData['id'] as String;
      final itemsData = await _supabase
          .from('return_items')
          .select()
          .eq('return_id', returnId);

      for (var item in itemsData) {
        final productId = item['product_id'] as String;
        final quantity = item['quantity'] as int;
        returnedQuantities[productId] = (returnedQuantities[productId] ?? 0) + quantity;
      }
    }

    // Calculate remaining returnable quantities
    final returnableItems = <ReturnableItem>[];
    for (var item in order.items) {
      if (!item.isReturnable) continue;

      final alreadyReturned = returnedQuantities[item.productId] ?? 0;
      final remainingQty = item.quantity - alreadyReturned;
      
      if (remainingQty > 0) {
        returnableItems.add(ReturnableItem(
          orderItem: item,
          alreadyReturnedQty: alreadyReturned,
          remainingQty: remainingQty,
        ));
      }
    }

    return returnableItems;
  }

  /// Submit a return request
  Future<ReturnModel> submitReturnRequest({
    required String orderId,
    required String userId,
    required List<ReturnItemModel> items,
    required String returnReason,
    String? notes,
  }) async {
    // Backend validation: Fetch full order to validate return eligibility
    final orderData = await _supabase
        .from('orders')
        .select()
        .eq('id', orderId)
        .eq('user_id', userId)
        .single();

    final orderStatus = orderData['order_status'] as String;
    final deliveredAtStr = orderData['delivered_at'] as String?;

    // Validate order is delivered
    if (orderStatus != 'delivered') {
      throw Exception('Returns are only allowed for delivered orders');
    }

    // Validate delivery date exists
    if (deliveredAtStr == null) {
      throw Exception('Order delivery date is missing. Cannot process return.');
    }

    final deliveredAt = DateTime.parse(deliveredAtStr);

    // Get return policy settings
    final policy = await getReturnPolicySettings();

    // Validate returns are enabled
    if (!policy.returnsEnabled) {
      throw Exception('Returns are currently disabled');
    }

    // Validate return window (timezone-safe calculation)
    final now = DateTime.now().toUtc();
    final deliveryDate = deliveredAt.toUtc();
    final daysSinceDelivery = now.difference(deliveryDate).inDays;

    if (daysSinceDelivery > policy.returnWindowDays) {
      throw Exception(
          'Return period has expired. Returns are allowed within ${policy.returnWindowDays} days from delivery.');
    }

    // Parse order items from JSONB
    final orderItemsJson = orderData['items'] as List<dynamic>;
    final orderItems = orderItemsJson
        .map((item) => OrderItemModel.fromJson(item as Map<String, dynamic>))
        .toList();

    // Create OrderModel for validation
    final order = OrderModel(
      id: orderId,
      userId: userId,
      status: orderStatus,
      deliveredAt: deliveredAt,
      items: orderItems,
      totalAmount: (orderData['total_amount'] as num).toDouble(),
      subtotal: (orderData['subtotal'] as num).toDouble(),
      gstAmount: (orderData['gst_amount'] as num).toDouble(),
      deliveryCharge: (orderData['delivery_charge'] as num).toDouble(),
      invoiceRequired: orderData['invoice_required'] ?? false,
      createdAt: DateTime.parse(orderData['created_at']),
    );

    // Validate items and quantities
    final returnableItems = await getReturnableItems(order);

    // Create a map of returnable items by product ID for quick lookup
    final returnableMap = <String, ReturnableItem>{};
    for (var item in returnableItems) {
      returnableMap[item.orderItem.productId] = item;
    }

    // Validate each return item
    for (var returnItem in items) {
      if (!returnableMap.containsKey(returnItem.productId)) {
        throw Exception(
            'Item "${returnItem.productName}" is not available for return (already fully returned or not in order)');
      }

      final returnable = returnableMap[returnItem.productId]!;
      if (returnItem.quantity > returnable.remainingQty) {
        throw Exception(
            'Cannot return ${returnItem.quantity} units of "${returnItem.productName}". Only ${returnable.remainingQty} units remaining.');
      }

      if (returnItem.quantity <= 0) {
        throw Exception('Return quantity must be greater than 0');
      }
    }

    // Calculate total refund amount
    final subtotal = (orderData['subtotal'] as num?)?.toDouble() ?? 0.0;
    final gstAmount = (orderData['gst_amount'] as num?)?.toDouble() ?? 0.0;
    final gstRate = (subtotal > 0) ? (gstAmount / subtotal) : 0.0;
    final refundAmount = items.fold<double>(
      0.0,
      (sum, item) {
        final itemPrice = item.totalPrice;
        final itemGst = itemPrice * gstRate;
        final itemRefund = (itemPrice + itemGst) * 0.95;
        return sum + itemRefund;
      },
    );

    // Create return record
    final returnData = {
      'order_id': orderId,
      'user_id': userId,
      'return_status': 'pending',
      'return_reason': returnReason,
      'notes': notes,
      'refund_amount': refundAmount,
    };

    final returnResponse = await _supabase
        .from('returns')
        .insert(returnData)
        .select()
        .single();

    final returnId = returnResponse['id'] as String;

    // Create return items
    final returnItemsData = items.map((item) {
      return {
        'return_id': returnId,
        'product_id': item.productId,
        'product_name': item.productName,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'total_price': item.totalPrice,
        'quality_option_name': item.qualityOptionName,
        'unit': item.unit,
      };
    }).toList();

    await _supabase.from('return_items').insert(returnItemsData);

    // Update the order to mark it as having a return
    // This ensures the order appears in Admin Panel → Orders → Returned tab
    print('🔄 Updating order $orderId with return flags...');
    try {
      final updateResult = await _supabase
          .from('orders')
          .update({
            'has_return': true,
            'return_status': 'Pending Review',
            'return_requested_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId)
          .select();
      
      print('✅ Order updated successfully: $updateResult');
    } catch (e, stackTrace) {
      // Log detailed error but don't fail the return creation
      print('❌ ERROR: Could not update order return flags');
      print('Error details: $e');
      print('Stack trace: $stackTrace');
      print('Order ID: $orderId');
      print('Return ID: $returnId');
      
      // Try to check if columns exist
      try {
        final orderCheck = await _supabase
            .from('orders')
            .select('id, has_return, return_status')
            .eq('id', orderId)
            .maybeSingle();
        print('Order check result: $orderCheck');
        if (orderCheck != null && orderCheck['has_return'] == null) {
          print('⚠️ WARNING: has_return column does not exist in orders table!');
          print('⚠️ Please run the migration: admin+app/add_order_return_fields.sql');
        }
      } catch (checkError) {
        print('Could not check order: $checkError');
      }
      
      // The database trigger should handle this, but we log the error
    }

    // Fetch complete return with items
    return getReturnById(returnId);
  }

  /// Get a return by ID with its items
  Future<ReturnModel> getReturnById(String returnId) async {
    final returnData = await _supabase
        .from('returns')
        .select()
        .eq('id', returnId)
        .single();

    final itemsData = await _supabase
        .from('return_items')
        .select()
        .eq('return_id', returnId);

    final items = (itemsData as List<dynamic>)
        .map((e) => ReturnItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return ReturnModel.fromJson({
      ...returnData,
      'items': items.map((e) => e.toJson()).toList(),
    });
  }

  /// Get all returns for an order
  Future<List<ReturnModel>> getOrderReturns(String orderId) async {
    final returnsData = await _supabase
        .from('returns')
        .select()
        .eq('order_id', orderId)
        .order('created_at', ascending: false);

    final returns = <ReturnModel>[];

    for (var returnData in returnsData) {
      final returnId = returnData['id'] as String;
      final itemsData = await _supabase
          .from('return_items')
          .select()
          .eq('return_id', returnId);

      final items = (itemsData as List<dynamic>)
          .map((e) => ReturnItemModel.fromJson(e as Map<String, dynamic>))
          .toList();

      returns.add(ReturnModel.fromJson({
        ...returnData,
        'items': items.map((e) => e.toJson()).toList(),
      }));
    }

    return returns;
  }

  /// Get all returns for a user
  Future<List<ReturnModel>> getUserReturns() async {
    final currentUser = SupabaseService.instance.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    final userData = await _supabase
        .from('users')
        .select('id')
        .eq('email', currentUser.email!)
        .single();

    final userId = userData['id'] as String;

    final returnsData = await _supabase
        .from('returns')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final returns = <ReturnModel>[];

    for (var returnData in returnsData) {
      final returnId = returnData['id'] as String;
      final itemsData = await _supabase
          .from('return_items')
          .select()
          .eq('return_id', returnId);

      final items = (itemsData as List<dynamic>)
          .map((e) => ReturnItemModel.fromJson(e as Map<String, dynamic>))
          .toList();

      returns.add(ReturnModel.fromJson({
        ...returnData,
        'items': items.map((e) => e.toJson()).toList(),
      }));
    }

    return returns;
  }

  /// Cancel a pending return request and delete any bank details
  Future<void> cancelReturn(String returnId) async {
    // Delete bank details immediately
    await _supabase
        .from('return_bank_details')
        .delete()
        .eq('return_id', returnId);

    // Cancel the return — only allow while not yet picked up
    await _supabase
        .from('returns')
        .update({
          'return_status': 'cancelled',
          'bank_details_submitted': false,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', returnId)
        .inFilter('return_status', ['pending', 'approved']);
  }

  /// Submit (or update) bank details for refund.
  /// Uses upsert so it works even if only INSERT RLS is granted on the table.
  Future<void> submitBankDetails({
    required String returnId,
    required String accountHolderName,
    required String bankName,
    required String accountNumber,
    required String ifscCode,
    String? upiId,
  }) async {
    // Validate IFSC format: 4 letters + 0 + 6 alphanumeric
    final ifscRegex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
    if (!ifscRegex.hasMatch(ifscCode.toUpperCase())) {
      throw Exception('Invalid IFSC code format. Example: SBIN0001234');
    }

    // Upsert handles both insert and update in one call.
    // If a record with the same return_id already exists it is updated;
    // otherwise a new record is inserted.
    await _supabase.from('return_bank_details').upsert(
      {
        'return_id': returnId,
        'account_holder_name': accountHolderName,
        'bank_name': bankName,
        'account_number': accountNumber,
        'ifsc_code': ifscCode.toUpperCase(),
        'upi_id': upiId,
      },
      onConflict: 'return_id',
    );

    // Mark return as having bank details (status transition is handled by admin)
    await _supabase.from('returns').update({
      'bank_details_submitted': true,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', returnId);
  }

  /// Get bank details for a return
  Future<ReturnBankDetails?> getBankDetails(String returnId) async {
    final response = await _supabase
        .from('return_bank_details')
        .select()
        .eq('return_id', returnId)
        .maybeSingle();

    if (response == null) {
      print('DEBUG getBankDetails: no record found for returnId=$returnId');
      return null;
    }
    print('DEBUG getBankDetails: found record: $response');
    return ReturnBankDetails.fromJson(response);
  }

  /// "Delete" bank details: hides them by resetting the submitted flag.
  /// We do NOT actually delete the DB row to avoid RLS restrictions.
  /// On next submission the upsert will overwrite the old record.
  Future<void> deleteBankDetails(String returnId) async {
    await _supabase.from('returns').update({
      'bank_details_submitted': false,
      'return_status': 'approved',   // let customer re-submit
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', returnId);
  }
}

/// Helper class for returnable items with quantity info
class ReturnableItem {
  final OrderItemModel orderItem;
  final int alreadyReturnedQty;
  final int remainingQty;

  const ReturnableItem({
    required this.orderItem,
    required this.alreadyReturnedQty,
    required this.remainingQty,
  });
}
