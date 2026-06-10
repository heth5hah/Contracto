import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import 'quotation_model.dart';
import '../../core/services/admin_notification_service.dart';

// Provider for fetching quote requests with new fields
final quotationsProvider = FutureProvider<List<Quotation>>((ref) async {
  try {
    final supabase = ref.watch(supabaseProvider);
    
    // Fetch all relevant fields including items and user information
    // Only exclude quotes that are FULLY completed (order already in Orders section)
    // Keep 'quotation_accepted' and 'payment_details_sent' visible so admin can verify & create the order
    final rawResponse = await supabase
        .from('quote_requests')
        .select('''
          *,
          quote_request_items(*,products(*,brands(*)),brands!brand_id(*)),
          quotes(*,quote_items(*,brands!brand_id(*))),
          users:user_id(*)
        ''')
        .not('status', 'in', '(accepted,order_placed)')
        .order('created_at', ascending: false)
        .limit(100);
    
    if (rawResponse == null) {
      return [];
    }
    
    final responseList = rawResponse as List;
    
    final quotations = responseList.map((item) {
      return Quotation.fromJson(item);
    }).toList();
    
    return quotations;
  } catch (e, stack) {
    print('ERROR FETCHING QUOTE REQUESTS: $e');
    rethrow;
  }
});

// Provider for quote management operations
final quoteManagementProvider = Provider((ref) => QuoteManagementService(ref));

class QuoteManagementService {
  final Ref ref;
  
  QuoteManagementService(this.ref);
  
  // Update transport charges for a quote
  Future<void> updateTransportCharges(String quoteId, double charges) async {
    final supabase = ref.read(supabaseProvider);
    
    await supabase
        .from('quote_requests')
        .update({'transport_charges': charges})
        .eq('id', quoteId);
    
    ref.invalidate(quotationsProvider);
  }
  
  // Update admin status
  Future<void> updateAdminStatus(String quoteId, String status) async {
    final supabase = ref.read(supabaseProvider);
    
    print('📤 Updating quotation $quoteId admin_status to $status');
    
    // Optimistic update: invalidate immediately for instant UI feedback
    ref.invalidate(quotationsProvider);
    ref.invalidate(quotationsWithRealtimeProvider);
    
    await supabase
        .from('quote_requests')
        .update({
          'admin_status': status,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', quoteId);
    
    print('✅ Quotation admin_status updated in database');
    
    // Real-time will also trigger refresh, but invalidate again to ensure
    ref.invalidate(quotationsProvider);
    ref.invalidate(quotationsWithRealtimeProvider);
    
    // Also manually trigger a refresh after a delay
    Future.delayed(const Duration(milliseconds: 500), () {
      ref.invalidate(quotationsProvider);
      ref.invalidate(quotationsWithRealtimeProvider);
    });
  }
  
  // Create or update a quote with individual item prices
  Future<void> createOrUpdateQuote(
    String quoteRequestId,
    List<Map<String, dynamic>> itemPrices, {
    double? transportCharges,
    double? taxAmount,
    String? adminStatus,
    int? validityDays,
    bool isReturnable = true,
  }) async {
    final supabase = ref.read(supabaseProvider);

    // ── VALIDATION: Confirm quote_request still exists in DB ────────────────
    // Prevents FK constraint errors from stale/cached UI data.
    final quoteRequestExists = await supabase
        .from('quote_requests')
        .select('id')
        .eq('id', quoteRequestId)
        .maybeSingle();

    if (quoteRequestExists == null) {
      // Refresh the UI to clear stale data and throw a friendly error.
      ref.invalidate(quotationsProvider);
      ref.invalidate(quotationsWithRealtimeProvider);
      throw Exception(
        'This quote request no longer exists. The list has been refreshed. Please try again.',
      );
    }
    // ────────────────────────────────────────────────────────────────────────

    // Calculate totals
    double subtotal = 0;
    for (final item in itemPrices) {
      if (item['is_available'] == false) continue;
      final quantity = (item['quantity'] as num).toDouble();
      final unitPrice = (item['unit_price'] as num).toDouble();
      subtotal += quantity * unitPrice;
    }
    
    final transport = transportCharges ?? 0.0;
    final tax = taxAmount ?? 0.0;
    final total = subtotal + tax + transport;
    
    // Check if a quote already exists for this quote request
    final existingQuote = await supabase
         .from('quotes')
        .select('id')
        .eq('quote_request_id', quoteRequestId)
        .maybeSingle();
    
    String quoteId;
    
    if (existingQuote != null) {
      // Update existing quote
      quoteId = existingQuote['id'];
      await supabase
          .from('quotes')
          .update({
            'subtotal': subtotal,
            'tax_amount': tax,
            'total_amount': total,
            'transport_charges': transport,
            'is_returnable': isReturnable,
            if (validityDays != null) 'validity_days': validityDays,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', quoteId);
      
      // Delete existing quote items
      await supabase
          .from('quote_items')
          .delete()
          .eq('quote_id', quoteId);
    } else {
      // Create new quote
      final quoteResponse = await supabase
          .from('quotes')
          .insert({
            'quote_request_id': quoteRequestId,
            'subtotal': subtotal,
            'tax_amount': tax,
            'total_amount': total,
            'transport_charges': transport,
            'validity_days': validityDays ?? 7,
            'is_returnable': isReturnable,
            'status': 'pending',
          })
          .select()
          .single();
      
      quoteId = quoteResponse['id'];
    }
    
    // Insert new quote items
    final quoteItemsToInsert = itemPrices.map((item) {
      final quantity = (item['quantity'] as num).toDouble();
      final unitPrice = (item['unit_price'] as num).toDouble();
      
      return {
        'quote_id': quoteId,
        'quality_option_id': item['quality_option_id'],
        'quality_option_name': item['quality_option_name'],
        'quantity': quantity.toInt(),
        'unit': item['unit'] ?? 'units',
        'unit_price': unitPrice,
        'total_price': quantity * unitPrice,
        'brand_id': item['brand_id'],
        'brand_name': item['brand_name'],
        'is_available': item['is_available'] ?? true,
      };
    }).toList();
    
    await supabase.from('quote_items').insert(quoteItemsToInsert);
    
    // Update quote request status and admin status
    final updates = <String, dynamic>{
      'status': 'quoted',
      'total_amount': total,
      'transport_charges': transport,
    };
    
    if (adminStatus != null) {
      updates['admin_status'] = adminStatus;
    }
    
    await supabase
        .from('quote_requests')
        .update(updates)
        .eq('id', quoteRequestId);
    
    // Notify user if status is 'quoted'
    if (updates['status'] == 'quoted') {
      try {
        final userId = await supabase
            .from('quote_requests')
            .select('user_id')
            .eq('id', quoteRequestId)
            .single()
            .then((data) => data['user_id'] as String?);
            
        if (userId != null) {
          final quote = Quotation(
            id: quoteId, 
            userId: userId, 
            items: [], 
            totalAmount: updates['total_amount'] ?? 0.0,
            createdAt: DateTime.now(),
            status: 'quoted', 
          );
          await notifyUserQuoteQuoted(quote);
        }
      } catch (e) {
        print('Error sending notification: $e');
      }
    }

    // Audit log: record returnability setting
    try {
      final currentUser = supabase.auth.currentUser;
      await supabase.from('audit_log').insert({
        'user_id': currentUser?.id,
        'action': 'QUOTE_UPDATED',
        'entity_type': 'quote',
        'entity_id': quoteId,
        'details': {
          'quote_request_id': quoteRequestId,
          'is_returnable': isReturnable,
          'total_amount': total,
          'transport_charges': transport,
          'item_count': itemPrices.length,
        },
      });
    } catch (e) {
      print('Warning: Could not write audit log: $e');
    }

    ref.invalidate(quotationsProvider);
  }
  
  // Update transport charges, total amount, admin status, and customer-facing status
  Future<void> updateQuote(String quoteId, {
    double? transportCharges, 
    double? totalAmount,
    String? adminStatus,
    String? status,
  }) async {
    final supabase = ref.read(supabaseProvider);
    
    final updates = <String, dynamic>{};
    if (transportCharges != null) updates['transport_charges'] = transportCharges;
    if (totalAmount != null) updates['total_amount'] = totalAmount;
    if (adminStatus != null) updates['admin_status'] = adminStatus;
    if (status != null) updates['status'] = status;
    
    if (updates.isNotEmpty) {
      await supabase
          .from('quote_requests')
          .update(updates)
          .eq('id', quoteId);
      
      ref.invalidate(quotationsProvider);
    }
  }

  /// Send a user-facing notification when a quote has been passed/quoted.
  Future<void> notifyUserQuoteQuoted(Quotation quote) async {
    final supabase = ref.read(supabaseProvider);
    String? userId = quote.userId;

    // If userId is not in the quote object, fetch it from the database
    if (userId == null || userId.isEmpty) {
      print('QuoteManagementService: userId not in quote object, fetching from database for quote ${quote.id}');
      try {
        final result = await supabase
            .from('quote_requests')
            .select('user_id')
            .eq('id', quote.id)
            .single();
        userId = result['user_id'] as String?;
        print('Fetched userId from database: $userId');
      } catch (e) {
        print('Error fetching userId from database: $e');
      }
    }

    if (userId == null || userId.isEmpty) {
      print('QuoteManagementService: No user_id for quote ${quote.id}, skipping notification');
      return;
    }

    final firstItemName = quote.items.isNotEmpty
        ? quote.items.first.productName
        : 'your quote request';

    final message = 'Your quotation for $firstItemName is now available.';
    
    print('========================================');
    print('CREATING NOTIFICATION');
    print('Quote ID: ${quote.id}');
    print('User ID: $userId');
    print('Message: $message');
    print('========================================');

    try {
      final notificationData = {
        'user_id': userId,
        'source': 'admin',
        'target': 'user',
        'type': 'quotation',
        'title': 'Quotation Ready',
        'message': message,
        'reference_id': quote.id,
        'metadata': {
          'quote_id': quote.id,
          'total_amount': quote.totalAmount,
          'status': 'quoted',
        },
        'is_read': false,
      };
      
      print('Notification Payload: $notificationData');

      final response = await supabase
          .from('notifications')
          .insert(notificationData)
          .select()
          .single();
      
      print('========================================');
      print('✅ NOTIFICATION CREATED SUCCESSFULLY');
      print('Notification ID: ${response['id']}');
      print('========================================');
    } catch (e) {
      print('========================================');
      print('❌ ERROR creating notification');
      print('Error: $e');
      print('========================================');
    }
  }
}

// Stream provider that refreshes when quotations are updated
final quotationsWithRealtimeProvider = StreamProvider<List<Quotation>>((ref) async* {
  // Initial load
  yield await ref.read(quotationsProvider.future);
  
  // Watch the notification service for status updates
  final service = ref.watch(adminNotificationServiceProvider);
  
  // Use a stream controller to trigger updates
  final updateController = StreamController<void>.broadcast();
  
  // Set up listeners for all update streams
  StreamSubscription? quoteStatusSub, newQuoteSub;
  
  quoteStatusSub = service.quotationStatusUpdatedStream.listen((data) {
    print('🔄 Quotation status updated event received: ${data['new_status']}');
    updateController.add(null);
  });
  
  newQuoteSub = service.newQuotesStream.listen((data) {
    print('🔄 New quotation created event received');
    updateController.add(null);
  });
  
  // Cleanup subscriptions on dispose
  ref.onDispose(() {
    quoteStatusSub?.cancel();
    newQuoteSub?.cancel();
    updateController.close();
  });
  
  // Listen to update events
  await for (final _ in updateController.stream) {
    print('🔄 Real-time quotation update triggered - refreshing quotations');
    
    // Debounce: wait a bit to batch rapid updates
    await Future.delayed(const Duration(milliseconds: 300));
    
    // Invalidate and refresh quotations
    ref.invalidate(quotationsProvider);
    
    // Yield updated quotations
    try {
      final quotations = await ref.read(quotationsProvider.future);
      print('✅ Quotations refreshed: ${quotations.length} quotations');
      yield quotations;
    } catch (e) {
      print('❌ Error refreshing quotations: $e');
      // Continue with previous data on error
      continue;
    }
  }
});

// Filter provider for admin status
final adminStatusFilterProvider = StateProvider<String?>((ref) => null);

// Search query provider for quotations
final quotationsSearchProvider = StateProvider<String>((ref) => '');

// Filtered quotations based on admin status and search query
final filteredQuotationsProvider = Provider<AsyncValue<List<Quotation>>>((ref) {
  // Listen to notification events and invalidate the data source
  ref.listen(newQuoteCountProvider, (_, __) => ref.invalidate(quotationsProvider));
  ref.listen(quotationStatusUpdatedStreamProvider, (_, __) => ref.invalidate(quotationsProvider));

  // Watch the actual data source directly
  final quotationsAsync = ref.watch(quotationsProvider);
  final statusFilter = ref.watch(adminStatusFilterProvider);
  final searchQuery = ref.watch(quotationsSearchProvider).toLowerCase();
  
  return quotationsAsync.whenData((quotations) {
    var filtered = quotations;
    
    // Apply status filter
    if (statusFilter != null && statusFilter != 'all') {
      filtered = filtered.where((q) => q.adminStatus == statusFilter).toList();
    }
    
    // Apply search filter
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((q) {
        final quoteId = q.id.toLowerCase();
        final customerName = (q.customerName ?? '').toLowerCase();
        final customerEmail = (q.customerEmail ?? '').toLowerCase();
        final status = q.status.toLowerCase();
        final adminStatus = q.adminStatus.toLowerCase();
        
        return quoteId.contains(searchQuery) ||
               customerName.contains(searchQuery) ||
               customerEmail.contains(searchQuery) ||
               status.contains(searchQuery) ||
               adminStatus.contains(searchQuery);
      }).toList();
    }
    
    return filtered;
  });
});
