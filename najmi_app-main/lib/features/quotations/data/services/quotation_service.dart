import 'package:contracto_app/core/network/supabase_service.dart';
import 'package:contracto_app/core/network/connectivity_service.dart';

class QuotationService {
  final ConnectivityService _connectivityService = ConnectivityService();

  // Helper method to ensure user exists in users table
  Future<Map<String, dynamic>> _ensureUserExists() async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // First, try to find user by auth ID (more reliable)
    var userData = await SupabaseService.client
        .from('users')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();

    // If not found by ID, try by email
    userData ??= await SupabaseService.client
          .from('users')
          .select('id')
          .eq('email', user.email!)
          .maybeSingle();

    // If user doesn't exist in users table, create them
    if (userData == null) {
      print('User not found in users table, creating user record...');
      print('User ID: ${user.id}');
      print('User email: ${user.email}');
      print('User metadata available: ${user.userMetadata?.keys.toList()}');

      try {
        // Create a minimal user record with safe defaults
        final userInsertData = <String, dynamic>{
          'id': user.id,
          'name':
              user.userMetadata?['name'] ?? user.email?.split('@')[0] ?? 'User',
          'email': user.email!,
          'mobile': user.userMetadata?['mobile'] ??
              user.phone ??
              user.id.substring(0, 10),
          'role': 'customer',
          'credit_limit': 0.0,
          'status': 'active',
          'user_type': 'individual', // Default to individual
          'is_gst_registered': false, // Default to false
        };

        // Only add optional fields if they exist in metadata
        // Skip PAN for now due to database constraint issues

        if (user.userMetadata?['gst_number'] != null) {
          userInsertData['gst_number'] = user.userMetadata!['gst_number'];
          userInsertData['is_gst_registered'] =
              user.userMetadata!['gst_number'].toString().isNotEmpty;
        }
        if (user.userMetadata?['user_type'] != null) {
          userInsertData['user_type'] = user.userMetadata!['user_type'];
        }
        if (user.userMetadata?['company_name'] != null) {
          userInsertData['company_name'] = user.userMetadata!['company_name'];
        }

        print('Attempting to insert user data: $userInsertData');
        await SupabaseService.client.from('users').insert(userInsertData);

        // Fetch the newly created user data
        userData = await SupabaseService.client
            .from('users')
            .select('id')
            .eq('id', user.id)
            .single();

        print('User record created successfully');
      } catch (e) {
        print('Error creating user record: $e');
        print('Attempting simplified user creation...');

        try {
          // Try creating with absolute minimal data
          await SupabaseService.client.from('users').insert({
            'id': user.id,
            'name': user.email?.split('@')[0] ?? 'User',
            'email': user.email!,
            'mobile':
                user.id.substring(0, 10), // Use user ID substring as mobile
            'role': 'customer',
            'credit_limit': 0.0,
            'status': 'active',
            'user_type': 'individual',
            'is_gst_registered': false,
          });

          userData = await SupabaseService.client
              .from('users')
              .select('id')
              .eq('id', user.id)
              .single();

          print('Simplified user record created successfully');
        } catch (e2) {
          print('Simplified user creation also failed: $e2');
          throw Exception(
              'Unable to create user record in database. Please contact support.');
        }
      }
    }

    return userData;
  }

  // Get user data with credit limit information
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final user = SupabaseService.instance.currentUser;
      if (user == null) return null;

      final userData = await SupabaseService.client
          .from('users')
          .select('id, name, email, credit_limit, user_type, company_name')
          .eq('email', user.email!)
          .maybeSingle();

      return userData;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Get user's quotations (both old and new system)
  Future<List<Map<String, dynamic>>> getUserQuotations() async {
    try {
      // Check connectivity first
      final isConnected = await _connectivityService.isConnected();
      if (!isConnected) {
        print('No internet connection - returning empty quotations list');
        return [];
      }

      final user = SupabaseService.instance.currentUser;
      if (user == null) return [];

      // Get user ID from users table
      final userData = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('email', user.email!)
          .maybeSingle();

      if (userData == null) return [];

      // Get new quote requests with their items
      // Exclude 'accepted' and 'order_placed' — those have moved to Orders section
      final quoteRequestsResponse = await SupabaseService.client
          .from('quote_requests')
          .select('''
            *,
            quote_request_items (*,products(*,brands(*)),brands:brand_id(*)),
            quotes (
              *,
              quote_items (*)
            ),
            brands:brand_id(*)
          ''')
          .eq('user_id', userData['id'])
          .not('status', 'in', '(accepted,order_placed)')
          .order('created_at', ascending: false);

      // Get old quotations for backward compatibility
      // Also exclude accepted/order_placed from old system
      final oldQuotationsResponse = await SupabaseService.client
          .from('quotations')
          .select('*')
          .eq('user_id', userData['id'])
          .not('status', 'in', '(accepted,order_placed)')
          .order('created_at', ascending: false);

      final quoteRequests =
          List<Map<String, dynamic>>.from(quoteRequestsResponse);
      final oldQuotations =
          List<Map<String, dynamic>>.from(oldQuotationsResponse);

      // Debug: Print quote requests to see data structure
      print('Fetched quote requests: ${quoteRequests.length}');
      for (var request in quoteRequests) {
        print(
            'Request ID: ${request['id']}, Status: ${request['status']}, Quotes: ${request['quotes']}');
      }

      // Combine both systems, marking old ones for backward compatibility
      final combinedQuotations = [
        ...quoteRequests.map((qr) => {
              ...qr,
              'system': 'new',
              'type': 'quote_request',
            }),
        ...oldQuotations.map((oq) => {
              ...oq,
              'system': 'old',
              'type': 'quotation',
            }),
      ];

      // Sort by creation date
      combinedQuotations.sort((a, b) => DateTime.parse(b['created_at'])
          .compareTo(DateTime.parse(a['created_at'])));

      return combinedQuotations;
    } catch (e) {
      print('Error getting user quotations: $e');
      // Return empty list for offline mode or network issues
      return [];
    }
  }

  // Get user's quote requests (new system only)
  Future<List<Map<String, dynamic>>> getUserQuoteRequests() async {
    try {
      final user = SupabaseService.instance.currentUser;
      if (user == null) return [];

      // Get user ID from users table
      final userData = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('email', user.email!)
          .maybeSingle();

      if (userData == null) return [];

      final response = await SupabaseService.client
          .from('quote_requests')
          .select('''
            *,
            quote_request_items (*)
          ''')
          .eq('user_id', userData['id'])
          .order('created_at', ascending: false);

      print('Quote requests response: ${response.length} requests');
      for (final request in response) {
        print(
            'Request: ${request['id']} - Items: ${request['quote_request_items']?.length ?? 'null'}');
      }

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting user quote requests: $e');
      return [];
    }
  }

  // Get old quotations (for backward compatibility)
  Future<List<Map<String, dynamic>>> getOldQuotations() async {
    try {
      final user = SupabaseService.instance.currentUser;
      if (user == null) return [];

      // Get user ID from users table
      final userData = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('email', user.email!)
          .maybeSingle();

      if (userData == null) return [];

      final response = await SupabaseService.client
          .from('quotations')
          .select('*')
          .eq('user_id', userData['id'])
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting old quotations: $e');
      return [];
    }
  }

  // Create new quotation request (new system)
  Future<void> createQuotation(Map<String, dynamic> quotationData) async {
    try {
      // Ensure user exists in users table
      final userData = await _ensureUserExists();

      // Try to create quote request with new schema first
      dynamic quoteRequestResponse;
      try {
        quoteRequestResponse = await SupabaseService.client
            .from('quote_requests')
            .insert({
              'user_id': userData['id'],
              'product_id': quotationData['product_id'],
              'product_name': quotationData['product_name'],
              'category': quotationData['category'],
              'brand_id': quotationData['brand_id'],
              'notes': quotationData['notes'],
              'status': 'pending',
              if (quotationData['delivery_address'] != null &&
                  (quotationData['delivery_address'] as String).isNotEmpty)
                'delivery_address': quotationData['delivery_address'],
            })
            .select()
            .single();
      } catch (e) {
        // If quote_requests table doesn't exist or has wrong schema, fall back to old quotations table
        print(
            'New quote_requests table not available, falling back to old quotations table: $e');
        await createOldQuotation(quotationData);
        return;
      }

      final quoteRequestId = quoteRequestResponse['id'];

      // Create quote request items — batch insert for speed (1 round-trip instead of N)
      if (quotationData['items'] != null && (quotationData['items'] as List).isNotEmpty) {
        final itemsList = quotationData['items'] as List;
        print('Batch-inserting ${itemsList.length} quote request items');
        final batchPayload = itemsList.map((item) => {
          'quote_request_id': quoteRequestId,
          'quality_option_id': item['quality_option_id'],
          'quality_option_name': item['quality_option_name'],
          // Backend column is INTEGER, so cast any double like 1.0 to an int
          'quantity': (item['quantity'] as num).round(),
          'unit': item['unit'] ?? 'units',
          'notes': item['notes'],
          'brand_id': item['brand_id'],
          'product_id': item['product_id'],
          'product_name': item['product_name'],
          'category': item['category'],
        }).toList();

        try {
          await SupabaseService.client
              .from('quote_request_items')
              .insert(batchPayload);
          print('✅ Batch insert of ${batchPayload.length} items successful');
        } catch (e, stackTrace) {
          print('❌ ERROR batch-inserting quote request items:');
          print('Error: $e');
          print('Stack trace: $stackTrace');
          rethrow;
        }
      } else {
        print('No items to create for quote request');
      }

      print('Quote request created successfully');
    } catch (e) {
      print('Error creating quotation: $e');
      rethrow;
    }
  }

  // Create old-style quotation (for backward compatibility)
  Future<void> createOldQuotation(Map<String, dynamic> quotationData) async {
    try {
      // Ensure user exists in users table
      final userData = await _ensureUserExists();

      await SupabaseService.client.from('quotations').insert({
        'user_id': userData['id'], // Use the ID from users table
        'product_id': quotationData['product_id'],
        'notes': quotationData['notes'],
        'status': 'pending',
        'price': quotationData['price'],
      });
    } catch (e) {
      print('Error creating old quotation: $e');
      rethrow;
    }
  }

  // Create quote response (admin only - new system)
  Future<void> createQuoteResponse(Map<String, dynamic> quoteData) async {
    try {
      final user = SupabaseService.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get user ID from users table
      final userData = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('email', user.email!)
          .maybeSingle();

      if (userData == null) {
        throw Exception('User not found in database');
      }

      // Insert quote
      final quoteResponse = await SupabaseService.client
          .from('quotes')
          .insert({
            'quote_request_id': quoteData['quote_request_id'],
            'admin_user_id': userData['id'], // Use the ID from users table
            'status': 'pending',
            'subtotal': quoteData['subtotal'],
            'tax_amount': quoteData['tax_amount'],
            'total_amount': quoteData['total_amount'],
            'transport_charges': quoteData['transport_charges'] ?? 0.0,
            'validity_days': quoteData['validity_days'],
            'payment_terms': quoteData['payment_terms'],
            'additional_notes': quoteData['additional_notes'],
            'bank_name': quoteData['bank_name'],
            'account_number': quoteData['account_number'],
            'ifsc_code': quoteData['ifsc_code'],
            'upi_id': quoteData['upi_id'],
          })
          .select()
          .single();

      final quoteId = quoteResponse['id'];

      // Insert quote items
      final quoteItems = quoteData['quote_items'] as List<Map<String, dynamic>>;
      for (final item in quoteItems) {
        await SupabaseService.client.from('quote_items').insert({
          'quote_id': quoteId,
          'quality_option_id': item['quality_option_id'],
          'quality_option_name': item['quality_option_name'],
          'quantity': item['quantity'],
          'unit': item['unit'],
          'unit_price': item['unit_price'],
          'total_price': item['total_price'],
        });
      }

      // Update quote request status
      await SupabaseService.client
          .from('quote_requests')
          .update({'status': 'quoted'}).eq('id', quoteData['quote_request_id']);
    } catch (e) {
      print('Error creating quote response: $e');
      rethrow;
    }
  }

  // Update quotation status (new system)
  Future<void> updateQuotationStatus(String quotationId, String status) async {
    try {
      await SupabaseService.client
          .from('quote_requests')
          .update({'status': status}).eq('id', quotationId);
    } catch (e) {
      print('Error updating quotation status: $e');
      rethrow;
    }
  }

  // Update old quotation status (for backward compatibility)
  Future<void> updateOldQuotationStatus(
      String quotationId, String status) async {
    try {
      await SupabaseService.client
          .from('quotations')
          .update({'status': status}).eq('id', quotationId);
    } catch (e) {
      print('Error updating old quotation status: $e');
      rethrow;
    }
  }

  // Update quote status
  Future<void> updateQuoteStatus(String quoteId, String status) async {
    try {
      await SupabaseService.client
          .from('quotes')
          .update({'status': status}).eq('id', quoteId);
    } catch (e) {
      print('Error updating quote status: $e');
      rethrow;
    }
  }

  // Get quotation by ID (new system)
  Future<Map<String, dynamic>?> getQuotationById(String quotationId) async {
    try {
      final response =
          await SupabaseService.client.from('quote_requests').select('''
            *,
            quote_request_items (*),
            quotes (
              *,
              quote_items (*)
            )
          ''').eq('id', quotationId).single();

      return response;
    } catch (e) {
      print('Error getting quotation by ID: $e');
      return null;
    }
  }

  // Get old quotation by ID (for backward compatibility)
  Future<Map<String, dynamic>?> getOldQuotationById(String quotationId) async {
    try {
      final response = await SupabaseService.client
          .from('quotations')
          .select('*')
          .eq('id', quotationId)
          .single();

      return response;
    } catch (e) {
      print('Error getting old quotation by ID: $e');
      return null;
    }
  }

  // Get quote by ID
  Future<Map<String, dynamic>?> getQuoteById(String quoteId) async {
    try {
      final response = await SupabaseService.client.from('quotes').select('''
            *,
            quote_items (*),
            quote_requests (*)
          ''').eq('id', quoteId).single();

      return response;
    } catch (e) {
      print('Error getting quote by ID: $e');
      return null;
    }
  }

  // Accept quote
  Future<void> acceptQuote(String quoteId) async {
    try {
      await SupabaseService.client
          .from('quotes')
          .update({'status': 'accepted'}).eq('id', quoteId);
    } catch (e) {
      print('Error accepting quote: $e');
      rethrow;
    }
  }

  // Reject quote
  Future<void> rejectQuote(String quoteId) async {
    try {
      await SupabaseService.client
          .from('quotes')
          .update({'status': 'rejected'}).eq('id', quoteId);
    } catch (e) {
      print('Error rejecting quote: $e');
      rethrow;
    }
  }

  // Check if new quote request system is available
  Future<bool> isNewQuoteSystemAvailable() async {
    try {
      // Try to query the new table to see if it exists
      await SupabaseService.client.from('quote_requests').select('id').limit(1);
      return true;
    } catch (e) {
      print('New quote system not available: $e');
      return false;
    }
  }

  // Migrate old quotation to new system (if needed)
  Future<void> migrateOldQuotation(String oldQuotationId) async {
    try {
      final oldQuotation = await getOldQuotationById(oldQuotationId);
      if (oldQuotation == null) return;

      // Create new quote request from old quotation
      await createQuotation({
        'product_id': oldQuotation['product_id'],
        'product_name': 'Migrated from old system',
        'notes': oldQuotation['notes'] ?? 'Migrated quotation',
        'quantity': 1,
        'unit': 'units',
      });

      // Mark old quotation as migrated
      await updateOldQuotationStatus(oldQuotationId, 'migrated');
    } catch (e) {
      print('Error migrating old quotation: $e');
      rethrow;
    }
  }
}
