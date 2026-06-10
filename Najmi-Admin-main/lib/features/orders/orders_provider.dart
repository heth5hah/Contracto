import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import 'order_model.dart';
import '../../core/services/admin_notification_service.dart';

final ordersStatusFilterProvider = StateProvider<String?>((ref) => null);

/// Helper function to calculate return status for an order
Future<String?> _getReturnStatusForOrder(
  dynamic supabase,
  String orderId,
) async {
  try {
    final returnsResponse = await supabase
        .from('returns')
        .select('return_status')
        .eq('order_id', orderId)
        .order('created_at', ascending: false);

    if (returnsResponse.isEmpty) {
      return 'No Return';
    }

    final returns = returnsResponse as List<dynamic>;
    final pendingReturns = returns
        .where(
          (r) =>
              r['return_status'] == 'pending' ||
              r['return_status'] == 'requested',
        )
        .toList();
    final approvedReturns = returns
        .where((r) => r['return_status'] == 'approved')
        .toList();
    final completedReturns = returns
        .where((r) => r['return_status'] == 'completed')
        .toList();

    if (completedReturns.isNotEmpty &&
        completedReturns.length == returns.length) {
      return 'Return Completed';
    } else if (approvedReturns.isNotEmpty) {
      return 'Return Approved';
    } else if (pendingReturns.isNotEmpty) {
      return returns.length > 1 ? 'Partial Return' : 'Return Requested';
    }

    return 'Return Requested';
  } catch (e) {
    print('Error fetching return status: $e');
    return null;
  }
}

/// Helper function to get return request count
Future<int> _getReturnRequestCount(dynamic supabase, String orderId) async {
  try {
    final countResponse = await supabase
        .from('returns')
        .select('id')
        .eq('order_id', orderId);

    return countResponse.length;
  } catch (e) {
    return 0;
  }
}

final ordersProvider = FutureProvider<List<Order>>((ref) async {
  final supabase = ref.watch(supabaseProvider);

  print('📦 Fetching orders from database...');

  // Fetch orders with items - join users table to get actual person name
  final response = await supabase
      .from('orders')
      .select('*, order_items(*), users!orders_user_id_fkey(name, company_name)')
      .order('created_at', ascending: false)
      .limit(100); // Limit to recent 100 orders for performance

  final List<dynamic> data = response as List<dynamic>;
  print('📦 Fetched ${data.length} orders from database');

  // Batch fetch all return counts in ONE query
  final orderIds = data.map((o) => o['id'] as String).toList();
  
  Map<String, int> returnCounts = {};
  if (orderIds.isNotEmpty) {
    try {
      final returnCountsResponse = await supabase
          .from('returns')
          .select('order_id')
          .inFilter('order_id', orderIds);
      
      // Count returns per order
      for (var ret in returnCountsResponse) {
        final orderId = ret['order_id'] as String;
        returnCounts[orderId] = (returnCounts[orderId] ?? 0) + 1;
      }
    } catch (e) {
      print('⚠️ Error fetching return counts: $e');
    }
  }

  final orders = <Order>[];

  // Process orders WITHOUT individual queries
  for (var orderJson in data) {
    final orderId = orderJson['id'] as String;

    // PRIMARY SOURCE: Use has_return and return_status from orders table
    final hasReturn = orderJson['has_return'] as bool? ?? false;
    final orderReturnStatus = orderJson['return_status'] as String?;

    // Use batch-fetched return count
    final returnCount = returnCounts[orderId] ?? 0;

    // Set return status
    String? returnStatus;
    if (hasReturn && orderReturnStatus != null) {
      returnStatus = orderReturnStatus;
    } else if (returnCount > 0) {
      returnStatus = returnCount > 1 ? 'Partial Return' : 'Return Requested';
    } else {
      returnStatus = 'No Return';
    }

    // Set data in JSON for Order model
    orderJson['return_status'] = returnStatus;
    orderJson['return_request_count'] = returnCount;
    orderJson['has_return'] = hasReturn || returnCount > 0;

    // Prefer the actual user name from the users table over the stored customer_name
    final userRecord = orderJson['users'] as Map<String, dynamic>?;
    if (userRecord != null) {
      final userName = userRecord['name'] as String?;
      if (userName != null && userName.trim().isNotEmpty) {
        orderJson['customer_name'] = userName.trim();
      }
    }

    orders.add(Order.fromJson(orderJson));
  }

  print('✅ Processed ${orders.length} orders');
  final returnedCount = orders.where((o) => o.hasReturn == true).length;
  print('✅ Found $returnedCount orders with returns (has_return=true)');

  return orders;
});

/// Stream provider that refreshes when new returns are created or orders are updated
final ordersWithRealtimeProvider = StreamProvider<List<Order>>((ref) async* {
  // Initial load
  yield await ref.read(ordersProvider.future);

  // Watch the notification service for status updates
  final service = ref.watch(adminNotificationServiceProvider);

  // Use a timer to periodically check for updates, but also listen to streams
  final updateController = StreamController<void>.broadcast();

  // Set up listeners for all update streams
  StreamSubscription? returnSub, orderStatusSub, returnStatusSub, newOrderSub;
  StreamSubscription? namedReturnSub;

  returnSub = service.newReturnsStream.listen((data) {
    print('🔄 Return created event received in orders provider');
    print('Return data: $data');
    print('Order ID: ${data['order_id']}');
    // Trigger immediate refresh when new return is created
    updateController.add(null);
  });

  orderStatusSub = service.orderStatusUpdatedStream.listen((data) {
    print('🔄 Order status updated event received: ${data['new_status']}');
    // Also check if has_return changed (important for Returned tab)
    if (data['has_return_changed'] == true) {
      print('🔄 has_return flag changed - refreshing Returned tab');
    }
    updateController.add(null);
  });

  returnStatusSub = service.returnStatusUpdatedStream.listen((data) {
    print('🔄 Return status updated event received: ${data['new_status']}');
    updateController.add(null);
  });

  newOrderSub = service.newOrdersStream.listen((data) {
    print('🔄 New order created event received');
    updateController.add(null);
  });

  // Listen to named order_return_created events for optimistic insert/update
  namedReturnSub = service.orderReturnCreatedStream.listen((event) async {
    try {
      print('🔔 Received named order_return_created event: $event');
      final payload = event['payload'] as Map<String, dynamic>?;
      if (payload == null) {
        updateController.add(null);
        return;
      }

      final orderId = payload['order_id'] as String?;
      if (orderId == null) {
        updateController.add(null);
        return;
      }

      // Fetch the single updated order and merge into existing list
      final supabase = ref.watch(supabaseProvider);
      final orderResp = await supabase
          .from('orders')
          .select('*, order_items(*), users!orders_user_id_fkey(name, company_name)')
          .eq('id', orderId)
          .maybeSingle();

      if (orderResp == null) {
        print('⚠️ order_return_created: fetched order is null for $orderId');
        updateController.add(null);
        return;
      }

      // Update local cache by invalidating provider so downstream consumers refresh quickly
      ref.invalidate(ordersProvider);
      // Small delay to allow providers to settle
      await Future.delayed(const Duration(milliseconds: 150));
      updateController.add(null);
    } catch (e) {
      print('⚠️ Error handling order_return_created named event: $e');
      updateController.add(null);
    }
  });

  // Cleanup subscriptions on dispose
  ref.onDispose(() {
    returnSub?.cancel();
    orderStatusSub?.cancel();
    returnStatusSub?.cancel();
    newOrderSub?.cancel();
    namedReturnSub?.cancel();
    updateController.close();
  });

  // Listen to update events
  await for (final _ in updateController.stream) {
    print('🔄 Real-time order update triggered - refreshing orders');

    // Debounce: wait a bit to batch rapid updates
    await Future.delayed(const Duration(milliseconds: 300));

    // Invalidate and refresh orders
    ref.invalidate(ordersProvider);

    // Yield updated orders
    try {
      final orders = await ref.read(ordersProvider.future);
      print('✅ Orders refreshed: ${orders.length} orders');
      yield orders;
    } catch (e) {
      print('❌ Error refreshing orders: $e');
      // Continue with previous data on error
      continue;
    }
  }
});

final filteredOrdersProvider = Provider<AsyncValue<List<Order>>>((ref) {
  final filter = ref.watch(ordersStatusFilterProvider);
  final ordersAsync = ref.watch(ordersWithRealtimeProvider);

  return ordersAsync.whenData((orders) {
    if (filter == null) return orders;

    // Special handling for "returned" filter - MUST use has_return = true
    // This matches the requirement: SELECT * FROM orders WHERE has_return = true
    if (filter.toLowerCase() == 'returned') {
      final returnedOrders = orders.where((o) => o.hasReturn == true).toList();
      print(
        '🔍 Filtered to ${returnedOrders.length} returned orders (has_return=true)',
      );
      return returnedOrders;
    }

    // For other filters, use order status
    return orders
        .where((o) => o.status.toLowerCase() == filter.toLowerCase())
        .toList();
  });
});

final totalRevenueProvider = FutureProvider<double>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  
  try {
    // We only fetch total_amount to keep the payload small
    final response = await supabase
        .from('orders')
        .select('total_amount')
        .not('order_status', 'eq', 'cancelled');
        
    final List<dynamic> data = response as List<dynamic>;
    double total = 0.0;
    for (var item in data) {
      total += (item['total_amount'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  } catch (e) {
    print('Error calculating total revenue: $e');
    return 0.0;
  }
});
