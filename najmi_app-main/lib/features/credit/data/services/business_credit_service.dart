import 'package:contracto_app/core/network/supabase_service.dart';

class BusinessCreditService {
  // Get credit account for current user (business accounts only)
  Future<Map<String, dynamic>?> getCreditAccount() async {
    try {
      final user = SupabaseService.instance.currentUser;
      if (user == null) {
        print('BusinessCreditService: No authenticated user');
        return null;
      }

      // Get user data to verify account type
      final userData = await SupabaseService.client
          .from('users')
          .select('id, user_type, company_name')
          .eq('email', user.email!)
          .maybeSingle();

      if (userData == null) {
        print('BusinessCreditService: User not found in database');
        return null;
      }

      final userType = userData['user_type'] as String?;
      final hasCompanyName = userData['company_name'] != null &&
          (userData['company_name'] as String).isNotEmpty;

      // Check if user is a business account (either by user_type or by having company_name)
      final isBusinessAccount = userType == 'company' || hasCompanyName;

      print(
          'BusinessCreditService: user_type = $userType, hasCompanyName = $hasCompanyName, isBusinessAccount = $isBusinessAccount');

      // Allow fetching account for individuals (wallet) and businesses
      // Get credit account
      final creditAccount = await SupabaseService.client
          .from('business_credit_accounts')
          .select('*')
          .eq('user_id', userData['id'])
          .maybeSingle();

      if (creditAccount == null) {
        print(
            'BusinessCreditService: No credit account found for user ${userData['id']}');
      } else {
        print(
            'BusinessCreditService: Credit account found: ${creditAccount['id']}');
      }

      return creditAccount;
    } catch (e) {
      print('BusinessCreditService: Error getting credit account: $e');
      return null;
    }
  }

  // Check if user is eligible for business credit
  Future<bool> isEligibleForCredit() async {
    try {
      final creditAccount = await getCreditAccount();
      if (creditAccount == null) return false;

      // PRODUCTION VALIDATION: Require approved KYC and active account status
      final kycStatus = creditAccount['kyc_status'] as String?;
      final accountStatus = creditAccount['status'] as String?;

      // Must have approved or pending KYC AND active account status (lax for development/testing)
      final isEligible = (kycStatus == 'approved' || kycStatus == 'pending') &&
          accountStatus == 'active';

      if (!isEligible) {
        print(
            '❌ Credit not eligible - KYC: $kycStatus, Status: $accountStatus');
      } else {
        print(
            '✅ Credit eligibility confirmed - KYC: $kycStatus & account active');
      }

      return isEligible;
    } catch (e) {
      print('Error checking credit eligibility: $e');
      return false;
    }
  }

  // Get available credit
  Future<double> getAvailableCredit() async {
    try {
      final creditAccount = await getCreditAccount();
      if (creditAccount == null) return 0.0;

      return (creditAccount['available_credit'] ?? 0.0).toDouble();
    } catch (e) {
      print('Error getting available credit: $e');
      return 0.0;
    }
  }

  // Get used credit
  Future<double> getUsedCredit() async {
    try {
      final creditAccount = await getCreditAccount();
      if (creditAccount == null) return 0.0;

      return (creditAccount['used_credit'] ?? 0.0).toDouble();
    } catch (e) {
      print('Error getting used credit: $e');
      return 0.0;
    }
  }

  // Get credit limit
  Future<double> getCreditLimit() async {
    try {
      final creditAccount = await getCreditAccount();
      if (creditAccount == null) return 0.0;

      return (creditAccount['credit_limit'] ?? 0.0).toDouble();
    } catch (e) {
      print('Error getting credit limit: $e');
      return 0.0;
    }
  }

  // Check if account is frozen — uses per-order overdue detection
  // An account is frozen if:
  //   1. is_frozen flag is already set in DB, OR
  //   2. Any credit order has payment_due_date < today AND is not paid
  Future<bool> isAccountFrozen() async {
    try {
      final creditAccount = await getCreditAccount();
      if (creditAccount == null) return false;

      // Fast path: flag already set
      if (creditAccount['is_frozen'] == true ||
          creditAccount['status'] == 'inactive') {
        return true;
      }

      final userId = creditAccount['user_id'] as String?;
      if (userId == null) return false;

      final today = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD
      final unfrozenAtStr = creditAccount['unfrozen_at'] as String?;
      final unfrozenAt = unfrozenAtStr != null ? DateTime.tryParse(unfrozenAtStr) : null;

      // Check for any OVERDUE credit orders (payment_due_date has passed and not paid)
      final overdueOrdersRes = await SupabaseService.client
          .from('orders')
          .select('id, payment_due_date, created_at')
          .eq('user_id', userId)
          .or('payment_source.eq.credit,payment_method.ilike.%credit%')
          .filter('payment_status', 'neq', 'paid')
          .not('order_status', 'in', '("cancelled","returned","rejected")')
          .lt('payment_due_date', today) // only truly overdue
          .not('payment_due_date', 'is', null);

      dynamic actualOverdueOrder;
      if (overdueOrdersRes != null && (overdueOrdersRes as List).isNotEmpty) {
        for (var order in overdueOrdersRes) {
          final due = DateTime.parse(order['payment_due_date'].toString());
          final created = order['created_at'] != null ? DateTime.parse(order['created_at'].toString()) : due;
          final isBypassed = unfrozenAt != null && 
              (due.isBefore(unfrozenAt) || created.isBefore(unfrozenAt));
          if (!isBypassed) {
            actualOverdueOrder = order;
            break;
          }
        }
      }

      if (actualOverdueOrder != null) {
        // Auto-freeze the account
        try {
          await SupabaseService.client
              .from('business_credit_accounts')
              .update({
                'is_frozen': true,
                'freeze_reason':
                    'Automated freeze: Overdue payment for order #${(actualOverdueOrder['id'] as String).replaceAll('-', '').substring(0, 6).toUpperCase()}',
                'frozen_at': DateTime.now().toIso8601String(),
              })
              .eq('user_id', userId);

          await SupabaseService.client.from('audit_log').insert({
            'user_id': userId,
            'action': 'account_frozen',
            'entity_type': 'business_credit_accounts',
            'entity_id': creditAccount['id'],
            'details': {
              'reason': 'Automated freeze: Overdue per-order payment',
              'order_id': actualOverdueOrder['id'],
              'due_date': actualOverdueOrder['payment_due_date'],
            },
          });
        } catch (e) {
          print('Auto-freeze write failed (non-critical): $e');
        }
        return true;
      }

      return false;
    } catch (e) {
      print('Error checking if account is frozen: $e');
      return false; // Fail open to not block on error
    }
  }

  // Use credit for an order — uses SECURITY DEFINER RPC to bypass RLS
  Future<bool> useCredit({
    required String orderId,
    required double amount,
    String? description,
  }) async {
    try {
      print('BusinessCreditService: Deducting ₹$amount via RPC for order $orderId');

      // Pre-flight checks (read-only, no RLS issues)
      final creditAccount = await getCreditAccount();
      if (creditAccount == null) {
        throw Exception('Credit account not found');
      }

      final accountStatus = (creditAccount['status'] as String?) ?? 'pending';
      if (accountStatus == 'pending') {
        throw Exception('Your business credit line is awaiting admin approval.');
      }
      if (accountStatus != 'active') {
        throw Exception('Your business credit account is currently $accountStatus.');
      }

      // Check frozen status
      final isFrozen = creditAccount['is_frozen'] == true;
      if (isFrozen) {
        throw Exception('Your account is frozen due to overdue payment. Clear your pending dues first.');
      }

      final availableCredit = (creditAccount['available_credit'] ?? 0.0).toDouble();
      if (amount > availableCredit) {
        throw Exception('Insufficient credit. Available: ₹${availableCredit.toStringAsFixed(0)}');
      }

      // Call SECURITY DEFINER RPC — this ALWAYS works, bypasses RLS
      final result = await SupabaseService.client.rpc('deduct_business_credit', params: {
        'p_order_id': orderId,
        'p_amount': amount,
        'p_description': description ?? 'Order payment'
      });

      if (result is Map && result['success'] == true) {
        print('✅ Credit deducted! new_available=${result['new_available']}, new_used=${result['new_used']}');
        return true;
      } else if (result is Map && result['success'] == false) {
        throw Exception(result['error'] ?? 'Credit deduction failed');
      }

      // If RPC returned unexpected format, verify
      final verify = await getCreditAccount();
      final verifiedAvailable = (verify?['available_credit'] ?? 0.0).toDouble();
      if (verifiedAvailable < availableCredit) {
        print('✅ RPC worked (verified: available=₹$verifiedAvailable)');
        return true;
      }

      throw Exception('Credit deduction could not be verified. Please contact support.');
    } catch (e) {
      print('❌ Error using credit: $e');
      rethrow;
    }
  }

  // Get current billing cycle
  Future<Map<String, dynamic>?> getCurrentBillingCycle() async {
    try {
      final creditAccount = await getCreditAccount();
      if (creditAccount == null) return null;

      final accountId = creditAccount['id'];

      // Get current open billing cycle
      final billingCycle = await SupabaseService.client
          .from('billing_cycles')
          .select('*')
          .eq('credit_account_id', accountId)
          .eq('status', 'open')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return billingCycle;
    } catch (e) {
      print('Error getting billing cycle: $e');
      return null;
    }
  }

  // Get next due date
  Future<DateTime?> getNextDueDate() async {
    try {
      final billingCycle = await getCurrentBillingCycle();
      if (billingCycle == null) return null;

      final dueDateStr = billingCycle['due_date'];
      if (dueDateStr == null) return null;

      return DateTime.parse(dueDateStr);
    } catch (e) {
      print('Error getting next due date: $e');
      return null;
    }
  }

  // Get waiting days - days remaining until due date (reduces by 1 each day)
  Future<int> getWaitingDays() async {
    try {
      final billingCycle = await getCurrentBillingCycle();
      if (billingCycle == null) {
        // No active billing cycle - use default from credit account
        final creditAccount = await getCreditAccount();
        if (creditAccount != null) {
          final paymentDueDays = creditAccount['payment_due_days'] ?? 15;
          return paymentDueDays as int;
        }
        return 15; // Default
      }

      // Get due date from billing cycle
      final dueDateStr = billingCycle['due_date'];
      if (dueDateStr == null) return 15;

      final dueDate = DateTime.parse(dueDateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);

      // Calculate days remaining until due date
      final daysRemaining = dueDateOnly.difference(today).inDays;

      // Return max of 0 (if overdue) or the remaining days
      return daysRemaining > 0 ? daysRemaining : 0;
    } catch (e) {
      print('Error getting waiting days: $e');
      return 15; // Default fallback
    }
  }

  // Get outstanding amount
  Future<double> getOutstandingAmount() async {
    try {
      final billingCycle = await getCurrentBillingCycle();
      if (billingCycle != null) {
        return (billingCycle['outstanding_amount'] ?? 0.0).toDouble();
      }

      // If no billing cycle, return used_credit as outstanding
      final creditAccount = await getCreditAccount();
      if (creditAccount != null) {
        return (creditAccount['used_credit'] ?? 0.0).toDouble();
      }

      return 0.0;
    } catch (e) {
      print('Error getting outstanding amount: $e');
      return 0.0;
    }
  }

  // Make a payment
  Future<bool> makePayment({
    required double amount,
    required String paymentMethod,
    String? transactionId,
    String? notes,
  }) async {
    try {
      final creditAccount = await getCreditAccount();
      if (creditAccount == null) {
        throw Exception('Credit account not found');
      }

      final accountId = creditAccount['id'];
      final billingCycle = await getCurrentBillingCycle();

      // Create payment record
      final payment = await SupabaseService.client
          .from('credit_payments')
          .insert({
            'credit_account_id': accountId,
            'billing_cycle_id': billingCycle?['id'],
            'payment_method': paymentMethod,
            'amount': amount,
            'payment_status': 'completed',
            'transaction_id': transactionId,
            'payment_date': DateTime.now().toIso8601String(),
            'notes': notes,
          })
          .select()
          .single();

      // Update credit account (restore available credit)
      final currentAvailable =
          (creditAccount['available_credit'] ?? 0.0).toDouble();
      final currentUsed = (creditAccount['used_credit'] ?? 0.0).toDouble();
      final newAvailable = currentAvailable + amount;
      final newUsed = (currentUsed - amount).clamp(0.0, double.infinity);

      await SupabaseService.client.from('business_credit_accounts').update({
        'available_credit': newAvailable,
        'used_credit': newUsed,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', accountId);

      // Record credit usage transaction (credit type)
      await SupabaseService.client.from('credit_usage').insert({
        'credit_account_id': accountId,
        'transaction_type': 'credit',
        'amount': amount,
        'description': notes ?? 'Payment received',
        'balance_after': newAvailable,
      });

      // Update billing cycle
      if (billingCycle != null) {
        final currentOutstanding =
            (billingCycle['outstanding_amount'] ?? 0.0).toDouble();
        final currentPayments =
            (billingCycle['total_payments'] ?? 0.0).toDouble();
        final newOutstanding =
            (currentOutstanding - amount).clamp(0.0, double.infinity);
        final newPayments = currentPayments + amount;

        await SupabaseService.client.from('billing_cycles').update({
          'outstanding_amount': newOutstanding,
          'total_payments': newPayments,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', billingCycle['id']);

        // Close cycle if fully paid
        if (newOutstanding <= 0) {
          await SupabaseService.client.from('billing_cycles').update({
            'status': 'closed',
            'paid_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', billingCycle['id']);
        }
      }

      return true;
    } catch (e) {
      print('Error making payment: $e');
      rethrow;
    }
  }

  // Get credit usage history
  Future<List<Map<String, dynamic>>> getCreditUsageHistory({
    int limit = 50,
  }) async {
    try {
      final creditAccount = await getCreditAccount();
      if (creditAccount == null) return [];

      final accountId = creditAccount['id'];

      final usage = await SupabaseService.client
          .from('credit_usage')
          .select('*')
          .eq('credit_account_id', accountId)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(usage);
    } catch (e) {
      print('Error getting credit usage history: $e');
      return [];
    }
  }

  // Get billing cycles history
  Future<List<Map<String, dynamic>>> getBillingCyclesHistory({
    int limit = 12,
  }) async {
    try {
      final creditAccount = await getCreditAccount();
      if (creditAccount == null) return [];

      final accountId = creditAccount['id'];

      final cycles = await SupabaseService.client
          .from('billing_cycles')
          .select('*')
          .eq('credit_account_id', accountId)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(cycles);
    } catch (e) {
      print('Error getting billing cycles history: $e');
      return [];
    }
  }

  // Get credit payments history
  Future<List<Map<String, dynamic>>> getCreditPaymentsHistory({
    int limit = 50,
  }) async {
    try {
      final creditAccount = await getCreditAccount();
      if (creditAccount == null) return [];

      final accountId = creditAccount['id'];

      final payments = await SupabaseService.client
          .from('credit_payments')
          .select('*')
          .eq('credit_account_id', accountId)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(payments);
    } catch (e) {
      print('Error getting credit payments history: $e');
      return [];
    }
  }

  // Update or create billing cycle
  Future<void> _updateBillingCycle(String accountId, double amount) async {
    try {
      // Get current open cycle
      final currentCycle = await SupabaseService.client
          .from('billing_cycles')
          .select('*')
          .eq('credit_account_id', accountId)
          .eq('status', 'open')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (currentCycle != null) {
        // Update existing cycle
        final currentCharges =
            (currentCycle['total_charges'] ?? 0.0).toDouble();
        final newCharges = currentCharges + amount;
        final newOutstanding =
            (currentCycle['outstanding_amount'] ?? 0.0).toDouble() + amount;

        await SupabaseService.client.from('billing_cycles').update({
          'total_charges': newCharges,
          'outstanding_amount': newOutstanding,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', currentCycle['id']);
      } else {
        // Create new billing cycle (30 days)
        final now = DateTime.now();
        final cycleEnd = now.add(const Duration(days: 30));
        final dueDate =
            cycleEnd.add(const Duration(days: 7)); // 7 days grace period

        await SupabaseService.client.from('billing_cycles').insert({
          'credit_account_id': accountId,
          'cycle_start_date': now.toIso8601String().split('T')[0],
          'cycle_end_date': cycleEnd.toIso8601String().split('T')[0],
          'due_date': dueDate.toIso8601String().split('T')[0],
          'total_charges': amount,
          'outstanding_amount': amount,
        });
      }
    } catch (e) {
      print('Error updating billing cycle: $e');
    }
  }

  // Backfills the system for any missed physical returns
  Future<int> backfillReturnCredits() async {
    try {
      final user = SupabaseService.instance.currentUser;
      if (user == null) return 0;

      final userData = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('email', user.email!)
          .maybeSingle();
      if (userData == null) return 0;
      final userId = userData['id'] as String;

      // Check if they have refunds to backfill (both 'refund_completed' and 'completed' statuses)
      final completedReturns = await SupabaseService.client
          .from('returns')
          .select('id, order_id, user_id, return_status, refund_amount, refund_amount_final, orders(total_amount, payment_source, order_status)')
          .eq('user_id', userId)
          .inFilter('return_status', ['refund_completed', 'completed']);

      print('🔍 backfillReturnCredits: userId=$userId, completedReturns=${(completedReturns as List).length}');
      for (final ret in completedReturns as List) {
        print('  → return id=${ret['id']}, refund_amount=${ret['refund_amount']}, refund_amount_final=${ret['refund_amount_final']}, order_total=${ret['orders']?['total_amount']}');
      }

      var account = await getCreditAccount();

      // If no account, but they have refunds, create a wallet!
      if (account == null) {
        if ((completedReturns as List).isEmpty) return 0;

        account = await SupabaseService.client.from('business_credit_accounts').insert({
          'user_id': userId,
          'credit_limit': 0,
          'available_credit': 0,
          'used_credit': 0,
          'status': 'active',
        }).select().single();
      }

      final accountId = account['id'];

      // Fetch all existing credit_usage rows (descriptions only)
      final existingUsage = await SupabaseService.client
          .from('credit_usage')
          .select('description, transaction_type, order_id')
          .eq('credit_account_id', accountId);

      final existingList = existingUsage as List;

      // Build set of already-refunded order shortIds and return ids
      final refundedOrderIds = <String>{};
      final refundedReturnIds = <String>{};
      for (final row in existingList) {
        final desc = (row['description'] ?? '') as String;
        if (desc.startsWith('Return refund')) {
          final match = RegExp(r'Order #([A-F0-9]{8})', caseSensitive: false)
              .firstMatch(desc);
          if (match != null)
            refundedOrderIds.add(match.group(1)!.toUpperCase());
        } else if (desc.startsWith('Refund for return #')) {
          final returnId = desc.replaceFirst('Refund for return #', '').trim();
          refundedReturnIds.add(returnId);
        }
      }

      // Build set of already-recorded quotation payment shortIds
      final recordedQuoteIds = <String>{};
      for (final row in existingList) {
        final desc = (row['description'] ?? '') as String;
        if (desc.startsWith('Quotation payment - #')) {
          final shortId = desc
              .replaceFirst('Quotation payment - #', '')
              .trim()
              .toUpperCase();
          if (shortId.length >= 8)
            recordedQuoteIds.add(shortId.substring(0, 8));
        }
      }

      // === PHASE 1: Backfill missing DEBIT entries for credit-paid quotations ===
      final creditQuotes = await SupabaseService.client
          .from('quote_requests')
          .select('id, quotes(total_amount, subtotal)')
          .eq('user_id', userId)
          .eq('payment_method', 'credit')
          .eq('status', 'quotation_accepted');

      int debitBackfilled = 0;
      for (final quote in creditQuotes as List) {
        final quoteId = quote['id'] as String;
        final shortId =
            quoteId.replaceAll('-', '').substring(0, 8).toUpperCase();

        if (recordedQuoteIds.contains(shortId)) continue;

        // This quotation was paid via credit but has no credit_usage debit entry
        // total_amount/subtotal come from the nested quotes relation
        final quotes = quote['quotes'] as List?;
        double total = 0.0;
        if (quotes != null && quotes.isNotEmpty) {
          total = (quotes[0]['total_amount'] as num?)?.toDouble() ??
              (quotes[0]['subtotal'] as num?)?.toDouble() ??
              0.0;
        }
        if (total <= 0) continue;

        try {
          final currentAvailable =
              (account['available_credit'] as num).toDouble();
          final creditLimit = (account['credit_limit'] as num).toDouble();

          final newAvailable =
              (currentAvailable - total).clamp(0.0, creditLimit);

          // Record the missing purchase debit
          await SupabaseService.client.from('credit_usage').insert({
            'credit_account_id': accountId,
            'transaction_type': 'debit',
            'amount': total,
            'description': 'Quotation payment - #$shortId',
            'balance_after': newAvailable,
          });
          debitBackfilled++;
          print(
              'Backfilled missing purchase debit for quotation #$shortId (₹$total)');
        } catch (e) {
          print('Error backfilling debit for #$shortId: $e');
        }
      }

      // === PHASE 2: Backfill missing CREDIT (refund) entries for returned orders ===
      int refundBackfilled = 0;
      for (final ret in completedReturns as List) {
        final returnId = ret['id'] as String;
        final orderId = ret['order_id'] as String?;
        if (orderId == null) continue;

        final ordersData = ret['orders'] as Map<String, dynamic>?;
        final paymentSource = ordersData != null ? ordersData['payment_source'] as String? : null;
        if (paymentSource != 'credit') {
          // Skip bank-paid or other payment methods in backfill (only credit-paid needs credit restoration)
          continue;
        }

        final shortId =
            orderId.replaceAll('-', '').substring(0, 8).toUpperCase();

        if (refundedOrderIds.contains(shortId)) continue;
        if (refundedReturnIds.contains(returnId)) continue;

        final refundAmount =
            (ret['refund_amount_final'] as num?)?.toDouble() ??
            (ret['refund_amount'] as num?)?.toDouble() ??
            (ordersData?['total_amount'] as num?)?.toDouble() ??
            0.0;
        if (refundAmount <= 0) continue;

        // Ensure order is actually marked as returned in DB if not already
        final currentOrderStatus = ordersData?['order_status'] as String?;
        if (currentOrderStatus != 'returned') {
          await SupabaseService.client
              .from('orders')
              .update({'order_status': 'returned'}).eq('id', orderId);
        }

        await restoreCreditForReturn(
          orderId: orderId,
          refundAmount: refundAmount,
          description: 'Return refund - Order #$shortId',
        );
        refundBackfilled++;
      }
      return debitBackfilled + refundBackfilled;
    } catch (e) {
      print('backfill error: $e');
      return 0;
    }
  }

  Future<void> hardResetTrueBalances() async {
    try {
      final account = await getCreditAccount();
      if (account == null) return;
      final accountId = account['id'];

      print('Calling recount_business_credit_balances RPC for account $accountId');
      final result = await SupabaseService.client.rpc('recount_business_credit_balances', params: {
        'p_account_id': accountId,
      });

      if (result is Map) {
        if (result['success'] == true) {
          print('✅ Recount successful! new_available=${result['new_available']}, new_used=${result['new_used']}');
        } else {
          print('❌ Recount failed: ${result['error']}');
        }
      }
    } catch (e) {
      print('Hard reset error: $e');
    }
  }

  // Restore credit for a return — uses SECURITY DEFINER RPC
  // Automatically routes: credit-paid → restore credit, bank-paid → bank refund
  Future<bool> restoreCreditForReturn({
    required String orderId,
    required double refundAmount,
    required String description,
    String? returnId,
  }) async {
    try {
      print('BusinessCreditService: Restoring ₹$refundAmount for order $orderId');

      final result = await SupabaseService.client.rpc('restore_credit_for_return', params: {
        'p_order_id': orderId,
        'p_return_id': returnId ?? orderId,
        'p_refund_amount': refundAmount,
        'p_description': description,
      });

      if (result is Map && result['success'] == true) {
        final destination = result['refund_destination'] ?? 'credit';
        if (destination == 'bank') {
          print('✅ Order was bank-paid. Refund goes to bank. Credit line unchanged.');
        } else {
          print('✅ Credit restored! new_available=${result['new_available']}');
        }
        return true;
      } else if (result is Map && result['success'] == false) {
        print('⚠️ Restore RPC returned error: ${result['error']}');
        return false;
      }

      return true;
    } catch (e) {
      print('Error restoring credit via RPC: $e');
      return false;
    }
  }

  // Process refund for individual user (wallet, WITHOUT GST)
  Future<Map<String, dynamic>?> processIndividualRefund({
    required String orderId,
    required String returnId,
    required double itemsSubtotal,
    double gstAmount = 0,
  }) async {
    try {
      print('BusinessCreditService: Individual refund ₹$itemsSubtotal (GST ₹$gstAmount excluded)');

      final result = await SupabaseService.client.rpc('process_individual_refund', params: {
        'p_order_id': orderId,
        'p_return_id': returnId,
        'p_items_subtotal': itemsSubtotal,
        'p_gst_amount': gstAmount,
      });

      if (result is Map && result['success'] == true) {
        print('✅ Wallet refund done! Amount: ₹${result['refund_amount']}, New balance: ₹${result['new_wallet_balance']}');
        return Map<String, dynamic>.from(result);
      } else if (result is Map && result['success'] == false) {
        print('⚠️ Individual refund failed: ${result['error']}');
        return null;
      }

      return null;
    } catch (e) {
      print('Error processing individual refund: $e');
      return null;
    }
  }
}
