import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/quotations/quotations_provider.dart';
import '../../features/orders/orders_provider.dart';
import '../../features/enquiries/enquiries_provider.dart';

// Provider that returns the count of 'new' quotes (previously pending)
// Updated to satisfy: "after viewing remove that number" -> We will move 'new' to 'processing' on view.
final pendingQuotesCountProvider = Provider<int>((ref) {
  final quotations = ref.watch(quotationsProvider).asData?.value ?? [];
  return quotations.where((q) => q.adminStatus == 'new').length;
});

// Provider that returns the count of 'pending' orders
final pendingOrdersCountProvider = Provider<int>((ref) {
  final orders = ref.watch(ordersProvider).asData?.value ?? [];
  return orders.where((o) => o.status == 'pending').length;
});

// Provider that returns the count of 'return requested' orders
final pendingReturnsCountProvider = Provider<int>((ref) {
  final orders = ref.watch(ordersProvider).asData?.value ?? [];
  return orders.where((o) => o.hasReturn == true && (o.returnStatus == 'Return Requested' || o.returnStatus == 'Partial Return')).length;
});

// Provider that returns the count of 'pending' enquiries
final pendingEnquiriesCountProvider = Provider<int>((ref) {
  final enquiries = ref.watch(enquiriesProvider).asData?.value ?? [];
  return enquiries.where((e) => e.status == 'pending').length;
});

// A consolidated provider for all badges map
final adminBadgesProvider = Provider<Map<String, int>>((ref) {
  return {
    '/quotations': ref.watch(pendingQuotesCountProvider),
    '/orders': ref.watch(pendingOrdersCountProvider),
    '/return-policy': ref.watch(pendingReturnsCountProvider), // Using return-policy route as key for returns/returns
    '/enquiries': ref.watch(pendingEnquiriesCountProvider),
  };
});
