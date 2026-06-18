import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:contracto_app/features/quotations/data/services/quotation_service.dart';
import 'package:contracto_app/features/quotations/data/services/quote_request_cart_service.dart';
import 'package:contracto_app/shared/widgets/app_loading_state.dart';
import 'package:contracto_app/core/network/supabase_service.dart';
import 'package:contracto_app/features/auth/presentation/screens/login_screen.dart';
import 'package:contracto_app/features/credit/data/services/business_credit_service.dart';
import 'package:contracto_app/features/credit/presentation/widgets/business_credit_widget_v2.dart';
import 'package:contracto_app/features/payment/data/services/razorpay_service.dart';
import 'package:contracto_app/core/config/payment_config.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:contracto_app/features/payment/presentation/screens/payment_failure_screen.dart';
import 'dart:async';
import 'dart:ui';
import 'package:contracto_app/features/quotations/data/services/email_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:contracto_app/features/address/data/models/address_model.dart';
import 'package:contracto_app/features/address/data/services/address_service.dart';
import 'package:contracto_app/features/address/presentation/screens/address_screen.dart';
import 'package:contracto_app/features/quotations/presentation/screens/quote_request_cart_screen.dart';
import 'package:contracto_app/features/products/presentation/screens/product_details_screen.dart';
import 'package:contracto_app/features/products/data/models/product_model.dart';


class QuotationsScreen extends StatefulWidget {
  final VoidCallback? onSwitchToHome;
  /// If provided, the screen will automatically open the details sheet
  /// for the quotation with this quote_request ID after loading.
  final String? initialQuoteId;

  const QuotationsScreen({super.key, this.onSwitchToHome, this.initialQuoteId});

  @override
  State<QuotationsScreen> createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends State<QuotationsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  String _selectedFilter = 'All';
  List<Map<String, dynamic>> _quotations = [];
  bool _loadingQuotations = true;
  bool _refreshingQuotations = false;
  bool _submittingQuote = false; // Add loading state for quote submission
  bool _deletingQuote = false; // Add loading state for quote deletion
  final _quotationService = QuotationService();
  final RazorpayService _razorpayService = RazorpayService();

  // Selection mode for bulk delete
  bool _isSelectionMode = false;
  final Set<String> _selectedQuotationIds = {};
  Key _creditWidgetKey = UniqueKey();

  // Add periodic refresh timer and subscriptions
  Timer? _refreshTimer;
  StreamSubscription? _quotesSubscription;
  StreamSubscription? _quoteResponsesSubscription;

  Future<void> _submitQuoteRequest() async {
    // Check if user is authenticated
    if (!SupabaseService.instance.isAuthenticated) {
      if (mounted) {
        // Show dialog asking user to login or register
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Authentication Required'),
            content: const Text(
              'Please login or register first to submit quote requests.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667EEA),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Login / Register'),
              ),
            ],
          ),
        );
      }
      return;
    }

    final quoteRequestCart =
        Provider.of<QuoteRequestCartService>(context, listen: false);

    if (quoteRequestCart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No items in quote request cart'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_submittingQuote) return;
    
    // Set loading state
    setState(() {
      _submittingQuote = true;
    });

    try {
      // Get the first product as the main product for the quote request
      final firstItem = quoteRequestCart.itemsList.first;
      final product = firstItem.product;

      // Create ONE quote request with all items
      // Collect all unique notes from items
      final allNotes = quoteRequestCart.itemsList
          .where((item) => item.notes != null && item.notes!.isNotEmpty)
          .map((item) => item.notes!)
          .toSet()
          .join('; ');

      final Map<String, dynamic> quoteRequestData = {
        'product_id': product.id,
        'product_name': product
            .productName, // Use actual product name instead of generic text
        'category': product.category,
        'brand_id': product.brandId,
        'notes': allNotes.isNotEmpty
            ? allNotes
            : 'Quote request for multiple products from cart',
        'items': quoteRequestCart.itemsList
            .map((item) => {
                  'quality_option_id': item.qualityOptionId ?? 'default',
                  'quality_option_name': item.qualityOptionName,
                  'quantity': item.quantity,
                  'unit': item.product.unit ?? 'units',
                  'notes': item.notes,
                  'brand_id': item.brandId,
                  'product_id': item.product.id,
                  'product_name': item.product.productName,
                  'category': item.product.category,
                })
            .toList(),
      };

      await _quotationService.createQuotation(quoteRequestData);

      // Clear the quote request cart
      quoteRequestCart.clear();

      if (mounted) {
        // Show success dialog instead of snackbar
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Success!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Your quote request has been submitted successfully! We will get back to you within 24-48 hours.',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );

        // Wait a bit for the database to update, then refresh
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          _loadQuotations();
        }
      }
    } catch (e) {
      if (mounted) {
        // Show error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Error',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              'Failed to submit quote request: $e',
              style: const TextStyle(fontSize: 16),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      // Always clear loading state
      if (mounted) {
        setState(() {
          _submittingQuote = false;
        });
      }
    }
  }

  final List<String> _filterOptions = [
    'All',
    'Pending',
    'Quoted',
    'Accepted',
    'Rejected',
    'Archive',
  ];

  @override
  void initState() {
    super.initState();
    // Initialize Razorpay (may fail on web/Chrome — that's OK)
    try {
      _razorpayService.initialize(
        onPaymentSuccess: _handlePaymentSuccess,
        onPaymentFailure: _handlePaymentFailure,
        onExternalWallet: _handleExternalWallet,
      );
    } catch (e) {
      print('⚠️ Razorpay init skipped (not supported on this platform): $e');
    }
    _setupAnimations();
    // Pass the initialQuoteId so the first load can auto-open the details sheet
    _loadQuotations(autoOpenQuoteId: widget.initialQuoteId);
    _setupRealTimeUpdates();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _razorpayService.dispose();
    _animationController.dispose();
    _refreshTimer?.cancel();
    _quotesSubscription?.cancel();
    _quoteResponsesSubscription?.cancel();
    super.dispose();
  }

  void _setupRealTimeUpdates() {
    // Set up periodic refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadQuotations();
      }
    });

    // Set up real-time subscriptions for quote updates
    _setupQuotesSubscription();
    _setupQuoteResponsesSubscription();
  }

  void _setupQuotesSubscription() async {
    try {
      final user = SupabaseService.instance.currentUser;
      if (user == null) return;

      // Get user ID from users table
      final userData = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('email', user.email!)
          .maybeSingle();

      if (userData == null) return;

      // Subscribe to changes in quote_requests table for this user
      _quotesSubscription = SupabaseService.client
          .from('quote_requests')
          .stream(primaryKey: ['id'])
          .eq('user_id', userData['id'])
          .listen(
            (data) {
              if (mounted) {
                print('Real-time update received for quote requests');
                _loadQuotations();
              }
            },
            onError: (error) {
              print('Realtime subscription error: $error');
              // Don't show error to user, just log it
            },
          );
    } catch (e) {
      print('Error setting up quotes subscription: $e');
    }
  }

  void _setupQuoteResponsesSubscription() async {
    try {
      final user = SupabaseService.instance.currentUser;
      if (user == null) return;

      // Get user ID from users table
      final userData = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('email', user.email!)
          .maybeSingle();

      if (userData == null) return;

      // Get user's quote request IDs to filter quote responses
      final userQuoteRequests = await SupabaseService.client
          .from('quote_requests')
          .select('id')
          .eq('user_id', userData['id']);

      if (userQuoteRequests.isEmpty) return;

      final quoteRequestIds =
          userQuoteRequests.map((qr) => qr['id'] as String).toList();

      // Subscribe to changes in quotes table for this user's quote requests
      _quoteResponsesSubscription = SupabaseService.client
          .from('quotes')
          .stream(primaryKey: ['id'])
          .inFilter('quote_request_id', quoteRequestIds)
          .listen(
            (data) {
              if (mounted) {
                print('Real-time update received for quote responses');
                _loadQuotations();
              }
            },
            onError: (error) {
              print('Realtime subscription error: $error');
              // Don't show error to user, just log it
            },
          );
    } catch (e) {
      print('Error setting up quote responses subscription: $e');
    }
  }

  Future<void> _loadQuotations({bool showRefreshIndicator = false, String? autoOpenQuoteId}) async {
    try {
      if (showRefreshIndicator && mounted) {
        setState(() {
          _refreshingQuotations = true;
        });
      }

      final quotations = await _quotationService.getUserQuotations();
      if (mounted) {
        setState(() {
          _quotations = quotations;
          _loadingQuotations = false;
          _refreshingQuotations = false;
        });

        // Auto-open specific quotation if requested (e.g. from notification tap)
        if (autoOpenQuoteId != null && autoOpenQuoteId.isNotEmpty) {
          final target = quotations.firstWhere(
            (q) => q['id'] == autoOpenQuoteId,
            orElse: () => {},
          );
          if (target.isNotEmpty) {
            // Small delay to let the list render first
            await Future.delayed(const Duration(milliseconds: 300));
            if (mounted) _showQuoteDetails(target);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingQuotations = false;
          _refreshingQuotations = false;
        });
      }
    }
  }

  Future<void> _manualRefresh() async {
    await _loadQuotations(showRefreshIndicator: true);
  }

  Future<void> _sendPaymentDetailsEmail(String quoteRequestId,
      {bool showLoader = true, List<Map<String, dynamic>>? selectedItems}) async {
    // Show loading
    if (mounted && showLoader) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      await Future.delayed(const Duration(
          milliseconds: 300)); // Ensure dialog finishes animating in
    }

    try {
      final quoteRequest = await SupabaseService.client
          .from('quote_requests')
          .select('*, quotes(*)')
          .eq('id', quoteRequestId)
          .maybeSingle();

      if (quoteRequest == null) throw Exception('Quote not found');

      final quotes = quoteRequest['quotes'] as List?;
      if (quotes != null && quotes.isNotEmpty) {
        final quote = quotes[0];
        final totalAmount = (quote['total_amount'] ?? 0.0).toDouble();

        final user = SupabaseService.instance.currentUser;
        final userData = await SupabaseService.client
            .from('users')
            .select('name, email')
            .eq('email', user?.email ?? '')
            .maybeSingle();

        final customerEmail =
            quoteRequest['customer_email'] ?? userData?['email'] ?? '';
        final customerName =
            quoteRequest['customer_name'] ?? userData?['name'] ?? 'Customer';

        // Use passed selectedItems if available, else fetch all quote_items
        List<Map<String, dynamic>> itemsList;
        if (selectedItems != null && selectedItems.isNotEmpty) {
          itemsList = selectedItems.where((item) => item['is_available'] != false).toList();
        } else {
          final quoteItems = await SupabaseService.client
              .from('quote_items')
              .select('*')
              .eq('quote_id', quote['id']);
          itemsList = List<Map<String, dynamic>>.from(quoteItems)
              .where((item) => item['is_available'] != false)
              .toList();
        }

        // Recalculate total from selected items if selectedItems provided.
        // Always add the quote's tax on top of the (selected) subtotal.
        final origQuote = quotes[0];
        final origSubtotal = ((origQuote['subtotal'] ?? 1) as num).toDouble();
        final origTax    = ((origQuote['tax_amount'] ?? 0) as num).toDouble();
        final origTransport = ((origQuote['transport_charges'] ?? 0) as num).toDouble();
        final taxRate = origSubtotal > 0 ? origTax / origSubtotal : 0.0;

        double emailTotal;
        if (selectedItems != null && selectedItems.isNotEmpty) {
          final selectedSubtotal = selectedItems.fold(0.0,
              (sum, item) => sum + ((item['total_price'] ?? 0) as num).toDouble());
          final selectedTax = selectedSubtotal * taxRate;
          emailTotal = selectedSubtotal + selectedTax + origTransport;
        } else {
          emailTotal = totalAmount; // already includes tax from DB
        }

        final success = await EmailService().sendBankDetailsEmail(
          customerEmail: customerEmail,
          customerName: customerName,
          quotationId: quoteRequestId.substring(0, 8),
          items: itemsList,
          totalAmount: emailTotal,
          date: DateTime.now().toLocal().toString().split(' ')[0],
        );

        if (success) {
          await SupabaseService.client.from('quote_requests').update(
              {'status': 'payment_details_sent'}).eq('id', quoteRequestId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Payment details sent to your email!'),
                backgroundColor: Colors.green));
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Failed to send email. You can retry.'),
                backgroundColor: Colors.red));
          }
        }
      } else {
        // If no quotes exist, just update standard acceptance
        await SupabaseService.client
            .from('quote_requests')
            .update({'status': 'accepted'}).eq('id', quoteRequestId);
      }
      _loadQuotations();
    } catch (e) {
      print('Error sending email: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to process. $e'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted && showLoader) {
        Navigator.of(context, rootNavigator: true).pop(); // close dialog safely
      }
    }
  }

  Future<void> _finalizeQuoteSelection(String quoteId, List<Map<String, dynamic>>? selectedItems) async {
    if (selectedItems == null || selectedItems.isEmpty) return;

    try {
      final quote = await SupabaseService.client
          .from('quotes')
          .select('*')
          .eq('id', quoteId)
          .maybeSingle();
      if (quote == null) return;

      final selectedIds = selectedItems.map((e) => e['id']).toList();
      
      // Delete unselected items
      await SupabaseService.client
          .from('quote_items')
          .delete()
          .eq('quote_id', quoteId)
          .not('id', 'in', selectedIds);

      // Recalculate totals
      final origSubtotal = ((quote['subtotal'] ?? 1) as num).toDouble();
      final origTax = ((quote['tax_amount'] ?? 0) as num).toDouble();
      final origTransport = ((quote['transport_charges'] ?? 0) as num).toDouble();
      final taxRate = origSubtotal > 0 ? origTax / origSubtotal : 0.0;

      final newSubtotal = selectedItems.fold(0.0,
          (sum, item) => sum + ((item['total_price'] ?? 0) as num).toDouble());
      final newTax = newSubtotal * taxRate;
      final newTotal = newSubtotal + newTax + origTransport;

      // Update quote
      await SupabaseService.client.from('quotes').update({
        'subtotal': newSubtotal,
        'tax_amount': newTax,
        'total_amount': newTotal,
      }).eq('id', quoteId);
    } catch (e) {
      print('Error finalizing quote selection: $e');
    }
  }

  Future<void> _acceptQuote(String quoteRequestId, {double? selectedAmount, List<Map<String, dynamic>>? selectedItems}) async {
    if (!mounted) return;

    try {
      // 1. Check if account is frozen first!
      final creditService = BusinessCreditService();
      final isFrozen = await creditService.isAccountFrozen();
      
      if (isFrozen) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.ac_unit, color: Colors.red),
                  ),
                  const SizedBox(width: 10),
                  const Text('Account Frozen'),
                ],
              ),
              content: const Text(
                'Your account is currently frozen due to overdue payments. Please clear your previous dues to accept this quotation and place new orders.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
        }
        return;
      }

      // 2. Fetch quote details & user type

      final quoteRequest = await SupabaseService.client
          .from('quote_requests')
          .select('*, quotes(*)')
          .eq('id', quoteRequestId)
          .maybeSingle();

      if (quoteRequest == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Quote not found'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      // Get user type to decide payment options
      final user = SupabaseService.instance.currentUser;
      final userData = await SupabaseService.client
          .from('users')
          .select('name, email, user_type, company_name')
          .eq('email', user?.email ?? '')
          .maybeSingle();

      final userType = userData?['user_type']?.toString() ?? 'individual';
      final hasCompany =
          (userData?['company_name']?.toString() ?? '').isNotEmpty;
      final isBusiness = userType == 'company' || hasCompany;

      // Check for wallet / credit account using users table ID (not auth UID)
      final userRow = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('email', user?.email ?? '')
          .maybeSingle();
      final usersTableId = userRow?['id'] as String?;

      Map<String, dynamic>? creditAccount;
      double walletBalance = 0.0;
      if (usersTableId != null) {
        creditAccount = await SupabaseService.client
            .from('business_credit_accounts')
            .select('*')
            .eq('user_id', usersTableId)
            .maybeSingle();
        if (creditAccount != null) {
          walletBalance = (creditAccount['available_credit'] as num?)?.toDouble() ?? 0.0;
        }

        // ── Fallback for individual wallets ──────────────────────────────────
        // If available_credit is 0 but the user has completed return refunds,
        // compute the true balance from the returns table (the DB column may
        // not have been updated due to the RLS issue that was fixed).
        if (walletBalance == 0.0 && userType == 'individual') {
          try {
            final completedReturns = await SupabaseService.client
                .from('returns')
                .select('refund_amount_final, refund_amount')
                .eq('user_id', usersTableId)
                .inFilter('return_status', ['refund_completed', 'completed']);
            double returnsTotal = 0.0;
            for (final ret in completedReturns as List) {
              returnsTotal += (ret['refund_amount_final'] as num?)?.toDouble() ??
                  (ret['refund_amount'] as num?)?.toDouble() ?? 0.0;
            }
            if (returnsTotal > 0) {
              // Subtract any debit transactions recorded in credit_usage
              double totalDebits = 0.0;
              if (creditAccount != null) {
                final debits = await SupabaseService.client
                    .from('credit_usage')
                    .select('amount')
                    .eq('credit_account_id', creditAccount['id'])
                    .eq('transaction_type', 'debit');
                for (final d in debits as List) {
                  totalDebits += (d['amount'] as num?)?.toDouble() ?? 0.0;
                }
              }
              walletBalance = (returnsTotal - totalDebits).clamp(0.0, double.infinity);
              print('💰 _acceptQuote: computed wallet from returns: ₹$walletBalance');

              // Also create a credit account record if one doesn't exist yet
              if (creditAccount == null && walletBalance > 0) {
                creditAccount = await SupabaseService.client
                    .from('business_credit_accounts')
                    .insert({
                      'user_id': usersTableId,
                      'credit_limit': 0,
                      'available_credit': walletBalance,
                      'used_credit': 0,
                      'status': 'active',
                    })
                    .select()
                    .single();
              } else if (creditAccount != null && walletBalance > 0) {
                // Sync the DB value so subsequent operations use the correct number
                await SupabaseService.client
                    .from('business_credit_accounts')
                    .update({'available_credit': walletBalance})
                    .eq('id', creditAccount['id']);
              }
            }
          } catch (e) {
            print('Warning: could not compute wallet from returns: $e');
          }
        }
      }

      final hasWallet = creditAccount != null && walletBalance > 0;

      final quotes = quoteRequest['quotes'] as List?;
      if (quotes == null || quotes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('No quotes available to accept'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      // Use the selected amount from brand selection if provided,
      // otherwise fall back to the full quote total_amount
      final double amount = selectedAmount ?? ((quotes[0]['total_amount'] ?? 0.0) as num).toDouble();

      // Show payment method choice dialog (credit/wallet, COD, bank transfer)
      if (mounted) {
        _showBusinessPaymentDialog(
            quoteRequestId, quoteRequest, quotes[0], amount, userData,
            selectedItems: selectedItems,
            walletBalance: walletBalance);
      }
    } catch (e) {
      print('Error accepting quote: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error accepting: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Shows payment method choice dialog for business accounts
  void _showBusinessPaymentDialog(
    String quoteRequestId,
    Map<String, dynamic> quoteRequest,
    Map<String, dynamic> quote,
    double amount,
    Map<String, dynamic>? userData, {
    List<Map<String, dynamic>>? selectedItems,
    double walletBalance = 0.0,
  }) {
    final isIndividual = userData?['user_type'] == 'individual';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Choose Payment Method',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 4),
            Text(
              'Total: ₹${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF667EEA)),
            ),

            // Show wallet balance info for individual users (info banner)
            if (isIndividual && walletBalance > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, color: Color(0xFF22C55E), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Credit Balance Available: ₹${walletBalance.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // ── Pay by Wallet Balance (for individual users with sufficient balance) ───
            if (isIndividual && walletBalance >= amount) ...[
              _paymentOptionTile(
                icon: Icons.account_balance_wallet,
                iconColor: const Color(0xFF22C55E),
                bgColor: const Color(0xFFF0FDF4),
                title: 'Pay by Wallet Balance',
                subtitle: 'Available: ₹${walletBalance.toStringAsFixed(0)} — ₹${amount.toStringAsFixed(0)} will be deducted',
                onTap: () {
                  Navigator.pop(ctx);
                  _acceptViaCredit(
                      quoteRequestId, quoteRequest, quote, amount, userData,
                      selectedItems: selectedItems);
                },
              ),
              const SizedBox(height: 12),
            ],

            // Show split payment option when individual wallet balance is insufficient but > 0
            if (isIndividual && walletBalance > 0 && walletBalance < amount) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF), // Soft blue background
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF3B82F6), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Partial Wallet Payment Available',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'You can use your wallet balance of ₹${walletBalance.toStringAsFixed(0)} to pay a portion, and pay the remaining ₹${(amount - walletBalance).toStringAsFixed(0)} via bank transfer.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1E40AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _paymentOptionTile(
                icon: Icons.account_balance_wallet,
                iconColor: const Color(0xFF22C55E),
                bgColor: const Color(0xFFF0FDF4),
                title: 'Apply Wallet + Bank Transfer',
                subtitle: 'Deduct wallet: ₹${walletBalance.toStringAsFixed(0)} — Pay remaining ₹${(amount - walletBalance).toStringAsFixed(0)} manually',
                onTap: () {
                  Navigator.pop(ctx);
                  _acceptViaWalletPlusBankTransfer(
                    quoteRequestId,
                    quoteRequest,
                    quote,
                    amount,
                    userData,
                    walletDeduction: walletBalance,
                    remainingAmount: amount - walletBalance,
                    selectedItems: selectedItems,
                  );
                },
              ),
              const SizedBox(height: 12),
            ],

            // ── Pay by Business Credit (for business accounts) ───
            // Only allow business credit when available credit fully covers the amount.
            // No partial credit is allowed for business accounts — if the quote
            // exceeds the credit limit, the business must pay the full amount
            // via bank transfer.
            if (!isIndividual && walletBalance >= amount) ...[
              _paymentOptionTile(
                icon: Icons.account_balance_wallet,
                iconColor: const Color(0xFF8B5CF6),
                bgColor: const Color(0xFFF3E8FF),
                title: 'Pay by Business Credit',
                subtitle: 'Available: ₹${walletBalance.toStringAsFixed(0)} — ₹${amount.toStringAsFixed(0)} will be deducted',
                onTap: () {
                  Navigator.pop(ctx);
                  _acceptViaCredit(
                      quoteRequestId, quoteRequest, quote, amount, userData,
                      selectedItems: selectedItems);
                },
              ),
              const SizedBox(height: 12),
            ],

            // Show info banner when business credit is insufficient
            if (!isIndividual && walletBalance < amount) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFFDC2626), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Credit limit exceeded',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF991B1B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Quote total ₹${amount.toStringAsFixed(0)} exceeds your available credit of ₹${walletBalance.toStringAsFixed(0)}. Please pay the full amount via bank transfer.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFB91C1C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],



            // ── Cash on Delivery (always available) ───────────────
            _paymentOptionTile(
              icon: Icons.money_outlined,
              iconColor: const Color(0xFF10B981),
              bgColor: const Color(0xFFECFDF5),
              title: 'Cash on Delivery (COD)',
              subtitle: 'Pay in cash when your order is delivered',
              onTap: () {
                Navigator.pop(ctx);
                _initiateCODPayment(
                  quoteRequest,
                  quote,
                  amount,
                  userData: userData,
                  selectedItems: selectedItems,
                );
              },
            ),
            const SizedBox(height: 12),

            // ── Pay by Bank Transfer (always available) ───────────
            _paymentOptionTile(
              icon: Icons.account_balance,
              iconColor: const Color(0xFF10B981),
              bgColor: const Color(0xFFECFDF5),
              title: 'Pay by Bank Transfer',
              subtitle: 'Receive bank details on email & pay ₹${amount.toStringAsFixed(0)} manually',
              onTap: () {
                Navigator.pop(ctx);
                _acceptViaBankTransfer(
                    quoteRequestId, quoteRequest, quote, amount, userData,
                    selectedItems: selectedItems);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _paymentOptionTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: bgColor, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B))),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Future<String?> _showTransactionIdDialog({
    required String referenceId,
    bool isCreditPayment = false,
  }) async {
    final txnController = TextEditingController(
      text: isCreditPayment ? 'CREDIT-${DateTime.now().millisecondsSinceEpoch}' : '',
    );
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(isCreditPayment ? 'Confirm Credit Transaction' : 'Enter Transaction ID'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isCreditPayment 
                  ? 'A reference ID has been generated for this credit payment.'
                  : 'Please enter the transaction reference ID for your payment.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: txnController,
                decoration: InputDecoration(
                  labelText: isCreditPayment ? 'Credit Reference ID' : 'Transaction ID / UTR',
                  border: const OutlineInputBorder(),
                ),
                readOnly: isCreditPayment,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Transaction ID is required';
                  }
                  if (!isCreditPayment && value.trim().length < 6) {
                    return 'Please enter a valid Transaction ID';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          if (!isCreditPayment)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, txnController.text.trim());
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  /// Pay by Business Credit: deduct from credit limit, mark as accepted
  Future<void> _acceptViaCredit(
    String quoteRequestId,
    Map<String, dynamic> quoteRequest,
    Map<String, dynamic> quote,
    double amount,
    Map<String, dynamic>? userData, {
    List<Map<String, dynamic>>? selectedItems,
  }) async {
    if (!mounted) return;
    
    final txnId = 'CREDIT-${DateTime.now().millisecondsSinceEpoch}';
    
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final creditService = BusinessCreditService();

      // Check available credit
      final creditAccount = await creditService.getCreditAccount();
      if (creditAccount == null) {
        throw Exception(
            'No business credit account found. Please contact admin.');
      }

      final availableCredit =
          (creditAccount['available_credit'] ?? 0.0).toDouble();
      if (amount > availableCredit) {
        throw Exception(
          'Insufficient credit. Available: ₹${availableCredit.toStringAsFixed(0)}, Required: ₹${amount.toStringAsFixed(0)}',
        );
      }

      final accountId = creditAccount['id'];
      final newAvailable = availableCredit - amount;
      final newUsed =
          ((creditAccount['used_credit'] ?? 0.0) as num).toDouble() + amount;

      // Deduct credit: try RPC first, fallback to direct update
      bool creditDeducted = false;
      try {
        print('QuotationsScreen: Deducting ₹$amount via RPC for quote $quoteRequestId');
        final rpcResult = await SupabaseService.client.rpc('deduct_business_credit', params: {
          'p_quote_id': quoteRequestId,
          'p_amount': amount,
          'p_description': 'Quotation payment - #${quoteRequestId.substring(0, 8).toUpperCase()}'
        });
        // The RPC returns jsonb — check for success
        if (rpcResult is Map && rpcResult['success'] == true) {
          print('✅ Credit deducted via RPC: $rpcResult');
          creditDeducted = true;
        } else if (rpcResult is Map && rpcResult['success'] == false) {
          throw Exception(rpcResult['error'] ?? 'RPC returned failure');
        } else {
          // Unknown response format — verify by re-reading
          print('⚠️ RPC returned unexpected format: $rpcResult — verifying...');
          final verify = await creditService.getCreditAccount();
          final verifyAvailable = (verify?['available_credit'] ?? 0.0).toDouble();
          if (verifyAvailable < availableCredit) {
            print('✅ Verified: credit was deducted (available now ₹$verifyAvailable)');
            creditDeducted = true;
          } else {
            throw Exception('RPC returned but credit was not actually deducted');
          }
        }
      } catch (rpcError) {
        print('⚠️ RPC failed: $rpcError — falling back to direct update');
        // Fallback: direct database update
        try {
          await SupabaseService.client.from('business_credit_accounts').update({
            'available_credit': newAvailable,
            'used_credit': newUsed,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', accountId);

          // VERIFY the update actually took effect (RLS may silently block it)
          final verify = await creditService.getCreditAccount();
          final verifyAvailable = (verify?['available_credit'] ?? 0.0).toDouble();
          if (verifyAvailable < availableCredit) {
            print('✅ Direct update worked (available now ₹$verifyAvailable)');
            creditDeducted = true;
            // Also try to insert credit_usage (not critical)
            try {
              await SupabaseService.client.from('credit_usage').insert({
                'credit_account_id': accountId,
                'quote_request_id': quoteRequestId,
                'transaction_type': 'debit',
                'amount': amount,
                'description': 'Quotation payment - #${quoteRequestId.substring(0, 8).toUpperCase()}',
                'balance_after': newAvailable,
              });
            } catch (_) {}
          } else {
            print('❌ Direct update was SILENTLY BLOCKED by RLS (available still ₹$verifyAvailable)');
          }
        } catch (directError) {
          print('❌ Direct update threw error: $directError');
        }
      }

      // BLOCK if credit was not deducted — do NOT accept the quote
      if (!creditDeducted) {
        throw Exception(
          'Credit deduction failed. Please ask admin to run the database fix (fix_credit_deduction.sql in Supabase SQL Editor).'
        );
      }

      // 3. Update DB with selected items and Mark quote as accepted with payment method
      await _finalizeQuoteSelection(quote['id'], selectedItems);
      await SupabaseService.client.from('quote_requests').update({
        'status': 'quotation_accepted',
        'payment_method': 'credit',
        'transaction_id': txnId
      }).eq('id', quoteRequestId);

      // 3.5 Send bill email with only the selected items (User must still pay via bank transfer for credit)
      try {
        final user = SupabaseService.instance.currentUser;
        final customerEmail = quoteRequest['customer_email'] ?? userData?['email'] ?? user?.email ?? '';
        final customerName = quoteRequest['customer_name'] ?? userData?['name'] ?? 'Customer';

        List<Map<String, dynamic>> itemsList;
        if (selectedItems != null && selectedItems.isNotEmpty) {
          itemsList = selectedItems;
        } else {
          final quoteItems = await SupabaseService.client
              .from('quote_items')
              .select('*')
              .eq('quote_id', quote['id']);
          itemsList = List<Map<String, dynamic>>.from(quoteItems);
        }

        await EmailService().sendBankDetailsEmail(
          customerEmail: customerEmail,
          customerName: customerName,
          quotationId: quoteRequestId.substring(0, 8),
          items: itemsList,
          totalAmount: amount,
          date: DateTime.now().toLocal().toString().split(' ')[0],
        );
      } catch (e) {
        print('Error sending bank details email for credit payment: $e');
      }

      // 4. Insert in-app notification for user
      final userId = userData?['id'] ?? quoteRequest['user_id'];
      if (userId != null) {
        await SupabaseService.client.from('notifications').insert({
          'user_id': userId,
          'source': 'app',
          'target': 'user',
          'title': 'Payment Successful via Credit',
          'message':
              '₹${amount.toStringAsFixed(0)} deducted from your business credit for quotation #${quoteRequestId.substring(0, 8).toUpperCase()}. Remaining credit: ₹${newAvailable.toStringAsFixed(0)}.',
          'type': 'payment',
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      _loadQuotations();
      if (mounted) {
        setState(() {
          _creditWidgetKey = UniqueKey();
        });
        Navigator.of(context, rootNavigator: true).pop();
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.check_circle, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Expanded(child: Text('Payment via Credit Done!')),
            ]),
            content: Text(
              '₹${amount.toStringAsFixed(2)} has been deducted from your business credit.\n\nRemaining Credit: ₹${newAvailable.toStringAsFixed(2)}\n\nYour order will be confirmed shortly.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogCtx),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      print('Error paying via credit: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Credit payment failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Pay by Bank Transfer: send email with bill + in-app notification
  Future<void> _acceptViaBankTransfer(
    String quoteRequestId,
    Map<String, dynamic> quoteRequest,
    Map<String, dynamic> quote,
    double amount,
    Map<String, dynamic>? userData, {
    List<Map<String, dynamic>>? selectedItems,
  }) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final user = SupabaseService.instance.currentUser;
      final customerEmail = quoteRequest['customer_email'] ??
          userData?['email'] ??
          user?.email ??
          '';
      final customerName =
          quoteRequest['customer_name'] ?? userData?['name'] ?? 'Customer';

      // Use selectedItems if provided; otherwise fetch all quote_items from DB
      List<Map<String, dynamic>> itemsList;
      if (selectedItems != null && selectedItems.isNotEmpty) {
        itemsList = selectedItems;
      } else {
        final quoteItems = await SupabaseService.client
            .from('quote_items')
            .select('*')
            .eq('quote_id', quote['id']);
        itemsList = List<Map<String, dynamic>>.from(quoteItems);
      }

      // 1. Update status and DB with selected items
      await _finalizeQuoteSelection(quote['id'], selectedItems);
      await SupabaseService.client.from('quote_requests').update({
        'status': 'payment_details_sent',
        'payment_method': 'bank_transfer',
        'transaction_id': null,
      }).eq('id', quoteRequestId);

      // 2. Send bill email with only the selected items
      final emailSent = await EmailService().sendBankDetailsEmail(
        customerEmail: customerEmail,
        customerName: customerName,
        quotationId: quoteRequestId.substring(0, 8),
        items: itemsList,
        totalAmount: amount,
        date: DateTime.now().toLocal().toString().split(' ')[0],
      );

      // 3. In-app notification for user
      final userId = userData?['id'] ?? quoteRequest['user_id'] ?? user?.id;
      if (userId != null) {
        await SupabaseService.client.from('notifications').insert({
          'user_id': userId,
          'source': 'app',
          'target': 'user',
          'title': 'Bank Transfer Details Sent',
          'message':
              'Your bill of ₹${amount.toStringAsFixed(0)} for quotation #${quoteRequestId.substring(0, 8).toUpperCase()} has been sent to $customerEmail. Please complete the bank transfer to confirm your order.',
          'type': 'payment',
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      _loadQuotations();
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(children: [
              Icon(emailSent ? Icons.mark_email_read : Icons.info_outline,
                  color: emailSent ? const Color(0xFF10B981) : Colors.orange),
              const SizedBox(width: 8),
              const Expanded(child: Text('Bank Transfer Details')),
            ]),
            content: Text(emailSent
                ? 'Bank transfer details have been sent to $customerEmail.\n\nPlease complete the transfer to confirm your order. Check your notifications for details.'
                : 'Your quotation has been accepted. Please check the email we have on file for bank details, or contact our team.'),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogCtx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667EEA),
                  foregroundColor: Colors.white,
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      print('Error processing bank transfer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error processing bank transfer: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Pay by Wallet (partial) + Bank Transfer: deduct wallet, then email remaining
  Future<void> _acceptViaWalletPlusBankTransfer(
    String quoteRequestId,
    Map<String, dynamic> quoteRequest,
    Map<String, dynamic> quote,
    double totalAmount,
    Map<String, dynamic>? userData, {
    required double walletDeduction,
    required double remainingAmount,
    List<Map<String, dynamic>>? selectedItems,
  }) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final creditService = BusinessCreditService();
      final creditAccount = await creditService.getCreditAccount();
      if (creditAccount == null) {
        throw Exception('Wallet account not found');
      }

      final accountId = creditAccount['id'];
      final currentAvailable = (creditAccount['available_credit'] ?? 0.0).toDouble();
      final currentUsed = (creditAccount['used_credit'] ?? 0.0).toDouble();

      final newAvailable = (currentAvailable - walletDeduction).clamp(0.0, double.infinity);
      final newUsed = currentUsed + walletDeduction;

      // 1. Deduct wallet balance via RPC
      bool creditDeducted = false;
      try {
        print('QuotationsScreen: Deducting ₹$walletDeduction via RPC for partial wallet quote $quoteRequestId');
        final rpcResult = await SupabaseService.client.rpc('deduct_business_credit', params: {
          'p_quote_id': quoteRequestId,
          'p_amount': walletDeduction,
          'p_description': 'Wallet payment - #${quoteRequestId.substring(0, 8).toUpperCase()}'
        });

        if (rpcResult is Map && rpcResult['success'] == true) {
          print('✅ Wallet credit deducted via RPC: $rpcResult');
          creditDeducted = true;
        } else if (rpcResult is Map && rpcResult['success'] == false) {
          throw Exception(rpcResult['error'] ?? 'RPC returned failure');
        } else {
          // Unknown response format — verify
          print('⚠️ RPC returned unexpected format: $rpcResult — verifying...');
          final verify = await creditService.getCreditAccount();
          final verifyAvailable = (verify?['available_credit'] ?? 0.0).toDouble();
          if (verifyAvailable < currentAvailable) {
            print('✅ Verified: wallet credit was deducted (available now ₹$verifyAvailable)');
            creditDeducted = true;
          } else {
            throw Exception('RPC returned but wallet credit was not actually deducted');
          }
        }
      } catch (rpcError) {
        print('⚠️ RPC failed: $rpcError — falling back to direct update');
        // Fallback: direct database update (if RPC is missing)
        try {
          await SupabaseService.client.from('business_credit_accounts').update({
            'available_credit': newAvailable,
            'used_credit': newUsed,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', accountId);

          final verify = await creditService.getCreditAccount();
          final verifyAvailable = (verify?['available_credit'] ?? 0.0).toDouble();
          if (verifyAvailable < currentAvailable) {
            print('✅ Direct update worked (available now ₹$verifyAvailable)');
            creditDeducted = true;
            try {
              await SupabaseService.client.from('credit_usage').insert({
                'credit_account_id': accountId,
                'quote_request_id': quoteRequestId,
                'transaction_type': 'debit',
                'amount': walletDeduction,
                'description': 'Wallet payment - #${quoteRequestId.substring(0, 8).toUpperCase()}',
                'balance_after': newAvailable,
              });
            } catch (_) {}
          }
        } catch (directError) {
          print('❌ Direct update threw error: $directError');
        }
      }

      if (!creditDeducted) {
        throw Exception(
          'Wallet deduction failed. Please ask admin to run the database fix.'
        );
      }

      // 2. Finalize quote selection and update status
      await _finalizeQuoteSelection(quote['id'], selectedItems);
      await SupabaseService.client.from('quote_requests').update({
        'status': 'payment_details_sent',
        'payment_method': 'wallet_plus_bank',
        'transaction_id': null,
      }).eq('id', quoteRequestId);

      // 3. Send bill email for remaining amount
      final user = SupabaseService.instance.currentUser;
      final customerEmail = quoteRequest['customer_email'] ??
          userData?['email'] ?? user?.email ?? '';
      final customerName =
          quoteRequest['customer_name'] ?? userData?['name'] ?? 'Customer';

      List<Map<String, dynamic>> itemsList;
      if (selectedItems != null && selectedItems.isNotEmpty) {
        itemsList = selectedItems;
      } else {
        final quoteItems = await SupabaseService.client
            .from('quote_items')
            .select('*')
            .eq('quote_id', quote['id']);
        itemsList = List<Map<String, dynamic>>.from(quoteItems);
      }

      await EmailService().sendBankDetailsEmail(
        customerEmail: customerEmail,
        customerName: customerName,
        quotationId: quoteRequestId.substring(0, 8),
        items: itemsList,
        totalAmount: remainingAmount,
        date: DateTime.now().toLocal().toString().split(' ')[0],
      );

      // 4. In-app notification
      final userId = userData?['id'] ?? quoteRequest['user_id'] ?? user?.id;
      if (userId != null) {
        await SupabaseService.client.from('notifications').insert({
          'user_id': userId,
          'source': 'app',
          'target': 'user',
          'title': 'Wallet + Bank Transfer Payment',
          'message':
              '₹${walletDeduction.toStringAsFixed(0)} deducted from wallet. Please pay remaining ₹${remainingAmount.toStringAsFixed(0)} via bank transfer for quotation #${quoteRequestId.substring(0, 8).toUpperCase()}.',
          'type': 'payment',
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      _loadQuotations();
      if (mounted) {
        setState(() {
          _creditWidgetKey = UniqueKey();
        });
        Navigator.of(context, rootNavigator: true).pop();
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.check_circle, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Expanded(child: Text('Wallet Applied!')),
            ]),
            content: Text(
              '₹${walletDeduction.toStringAsFixed(0)} deducted from your wallet.\n\n'
              'Remaining: ₹${remainingAmount.toStringAsFixed(0)}\n\n'
              'Bank transfer details have been sent to $customerEmail. '
              'Please complete the transfer to confirm your order.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogCtx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      print('Error processing wallet + bank transfer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Payment failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showPaymentChoiceDialog(Map<String, dynamic> quoteRequest,
      Map<String, dynamic> quote, double amount) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Payment Method',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.credit_card, color: Color(0xFF3B82F6)),
              ),
              title: const Text('Online Payment'),
              subtitle: const Text('Credit/Debit Card, UPI, Netbanking'),
              onTap: () {
                Navigator.pop(context);
                _initiateOnlinePayment(quoteRequest, quote, amount);
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    const Icon(Icons.business_center, color: Color(0xFFF59E0B)),
              ),
              title: const Text('Business Credit'),
              subtitle: const Text('Use your available credit limit'),
              onTap: () async {
                Navigator.pop(context);
                await _finalizeAcceptance(quoteRequest['id'], quoteRequest);
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.money, color: Color(0xFF10B981)),
              ),
              title: const Text('Cash on Delivery'),
              subtitle: const Text('Pay when you receive the goods'),
              onTap: () {
                Navigator.pop(context);
                _initiateCODPayment(quoteRequest, quote, amount);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _initiateCODPayment(
    Map<String, dynamic> quoteRequest,
    Map<String, dynamic> quote,
    double amount, {
    Map<String, dynamic>? userData,
    List<Map<String, dynamic>>? selectedItems,
  }) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1. Update status and DB with selected items (brand selection logic)
      await _finalizeQuoteSelection(quote['id'], selectedItems);
      
      // 2. DO NOT create the order immediately.
      // Update status so admin can see this quote is awaiting payment confirmation.
      await SupabaseService.client.from('quote_requests').update({
        'status': 'quotation_accepted',
        'payment_method': 'cash_on_delivery',
      }).eq('id', quoteRequest['id']);

      _loadQuotations();

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Dismiss loader dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Order Request Submitted!'),
            content: const Text(
              'Your order request has been submitted. Our team will confirm your Cash on Delivery order and you will see it in the Orders section once confirmed.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop(); // Dismiss loader dialog
      print('Error processing COD: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error processing COD: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _initiateOnlinePayment(Map<String, dynamic> quoteRequest,
      Map<String, dynamic> quote, double amount) async {
    try {
      // 1. Create Razorpay Order
      final receiptId = 'QUOTE_${quote['id'].toString().substring(0, 8)}';

      // Get user details
      final user = SupabaseService.instance.currentUser;
      final userData = await SupabaseService.client
          .from('users')
          .select('name, mobile, email')
          .eq('email', user?.email ?? '')
          .maybeSingle();

      final customerName =
          quoteRequest['customer_name'] ?? userData?['name'] ?? 'Customer';
      final customerPhone =
          quoteRequest['customer_phone'] ?? userData?['mobile'] ?? '';
      final customerEmail =
          quoteRequest['customer_email'] ?? userData?['email'] ?? '';

      final orderResult = await _razorpayService.createPaymentOrder(
        amount: amount,
        currency: PaymentConfig.defaultCurrency,
        receipt: receiptId,
        customerName: customerName,
        customerEmail: customerEmail,
        customerPhone: customerPhone,
      );

      if (!orderResult['success']) {
        throw Exception(orderResult['error']);
      }

      final razorpayOrderId = orderResult['order_id'];

      // Store temporary data for callback
      _pendingQuoteRequest = quoteRequest;
      _pendingQuote = quote;

      // 2. Start Payment
      _razorpayService.startPayment(
        orderId: razorpayOrderId,
        keyId: PaymentConfig.razorpayKey,
        amount: amount,
        currency: PaymentConfig.defaultCurrency,
        customerName: customerName,
        customerEmail: customerEmail,
        customerPhone: customerPhone,
        description: 'Quote Payment #${quote['id'].toString().substring(0, 8)}',
      );
    } catch (e) {
      print('Error initiating payment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initiating payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Temporary storage for payment callbacks
  Map<String, dynamic>? _pendingQuoteRequest;
  Map<String, dynamic>? _pendingQuote;

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (_pendingQuoteRequest == null || _pendingQuote == null) return;

    try {
      final quoteRequest = _pendingQuoteRequest!;
      final quote = _pendingQuote!;
      final amount = (quote['total_amount'] ?? 0.0).toDouble();

      // DO NOT create order immediately — admin must verify before it appears in Orders.
      // Record payment ID so admin can verify it in Razorpay dashboard.
      await SupabaseService.client.from('quote_requests').update(
          {'status': 'quotation_accepted'}).eq('id', quoteRequest['id']);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Payment Received!'),
            content: Text(
              'Your payment of ₹$amount has been received (ID: ${response.paymentId}). '
              'Your order will appear in the Orders section once our team confirms it.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

      _loadQuotations();
    } catch (e) {
      print('Error after payment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment received but update failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _pendingQuoteRequest = null;
      _pendingQuote = null;
    }
  }

  void _handlePaymentFailure(PaymentFailureResponse response) {
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentFailureScreen(
            errorMessage: response.message,
            amount: (_pendingQuote != null)
                ? (_pendingQuote!['total_amount']?.toDouble() ?? 0.0)
                : 0.0,
          ),
        ),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("External Wallet Selected: ${response.walletName}")),
      );
    }
  }

  Future<void> _finalizeAcceptance(
      String quoteRequestId, Map<String, dynamic> quoteRequest) async {
    try {
      final user = SupabaseService.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // DO NOT create an order immediately.
      // Just mark the quote as accepted so admin can see it and verify before placing the order.
      await SupabaseService.client
          .from('quote_requests')
          .update({'status': 'quotation_accepted'}).eq('id', quoteRequestId);

      _loadQuotations();

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Request Submitted!'),
            content: const Text(
              'Your order request has been submitted. Our team will verify and confirm it. '
              'You will see it in the Orders section once confirmed.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('Error accepting quote: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept quote: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _createOrderFromQuote({
    required Map<String, dynamic> quoteRequest,
    required Map<String, dynamic> quote,
    required double amount,
    required String paymentMethod,
    required String paymentStatus,
    String? notes,
  }) async {
    final dbUser = await SupabaseService.client
        .from('users')
        .select('id, name, mobile, email')
        .eq('email', SupabaseService.instance.currentUser?.email ?? '')
        .single();

    // Get Quote Items
    final quoteItemsResponse = await SupabaseService.client
        .from('quote_items')
        .select('*')
        .eq('quote_id', quote['id']);
    final quoteItems = (quoteItemsResponse as List)
        .where((item) => item['is_available'] != false)
        .toList();

    // Get Request Items for Product mapping
    final requestItemsResponse = await SupabaseService.client
        .from('quote_request_items')
        .select('*')
        .eq('quote_request_id', quoteRequest['id']);
    final requestItems = requestItemsResponse as List;

    final List<Map<String, dynamic>> orderItems = [];

    for (int i = 0; i < quoteItems.length; i++) {
      final item = quoteItems[i];
      String productId;
      String productName;

      if (i < requestItems.length) {
        productId = requestItems[i]['product_id'] ?? requestItems[i]['id'];
        productName = requestItems[i]['product_name'] ?? 'Quote Item';
      } else {
        productId = quoteRequest['product_id'] ??
            '00000000-0000-0000-0000-000000000000';
        productName = quoteRequest['product_name'] ?? 'Extra Quote Item';
      }

      orderItems.add({
        'product_id': productId,
        'product_name': productName,
        'quantity': item['quantity'],
        'unit_price': item['unit_price'],
        'total_price': item['total_price'],
        'unit': item['unit'],
        'quality_option_name': item['quality_option_name'],
      });
    }

    final orderData = {
      'user_id': dbUser['id'],
      'customer_name': quoteRequest['customer_name'] ?? dbUser['name'] ?? '',
      'customer_email': quoteRequest['customer_email'] ?? dbUser['email'] ?? '',
      'customer_phone':
          quoteRequest['customer_phone'] ?? dbUser['mobile'] ?? '',
      'delivery_address':
          quoteRequest['delivery_address'] ?? 'Address from Quote',
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'order_status': 'confirmed',
      'total_amount': amount,
      'subtotal': quote['subtotal'] ?? amount,
      'gst_amount': quote['tax_amount'] ?? 0,
      'delivery_charge': quote['transport_charges'] ?? 0,
      'items': orderItems,
      'created_at': DateTime.now().toIso8601String(),
      'notes': notes,
    };

    final order = await SupabaseService.client
        .from('orders')
        .insert([orderData])
        .select()
        .single();

    return order;
  }

  Future<void> _rejectQuote(String quoteRequestId) async {
    try {
      // Get quote request details
      final quoteRequest = await SupabaseService.client
          .from('quote_requests')
          .select('*, quotes(*)')
          .eq('id', quoteRequestId)
          .maybeSingle();

      // Update status
      await SupabaseService.client
          .from('quote_requests')
          .update({'status': 'rejected'}).eq('id', quoteRequestId);

      // Record credit transaction for quote rejection
      try {
        final user = SupabaseService.instance.currentUser;
        if (user != null) {
          final userData = await SupabaseService.client
              .from('users')
              .select('id, user_type')
              .eq('email', user.email!)
              .maybeSingle();

          if (userData != null && userData['user_type'] == 'company') {
            final quotes = quoteRequest?['quotes'] as List?;
            if (quotes != null && quotes.isNotEmpty) {
              final totalAmount = (quotes[0]['total_amount'] ?? 0.0).toDouble();
              if (totalAmount > 0) {
                // Record credit transaction for quote rejection
                final creditService = BusinessCreditService();
                final creditAccount = await creditService.getCreditAccount();
                if (creditAccount != null) {
                  final accountId = creditAccount['id'];
                  final availableCredit =
                      (creditAccount['available_credit'] ?? 0.0).toDouble();

                  await SupabaseService.client.from('credit_usage').insert({
                    'credit_account_id': accountId,
                    'quote_request_id': quoteRequestId,
                    'transaction_type': 'adjustment',
                    'amount': totalAmount,
                    'description': 'Quote Rejected - Credit adjustment',
                    'balance_after': availableCredit,
                  });
                }
              }
            }
          }
        }
      } catch (e) {
        print('Error recording credit transaction: $e');
        // Don't fail the quote rejection if credit recording fails
      }

      // Refresh the quotations list
      _loadQuotations();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quote rejected successfully!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error rejecting quote: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to reject quote. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelQuote(String quoteRequestId) async {
    try {
      await SupabaseService.client
          .from('quote_requests')
          .update({'status': 'archived'}).eq('id', quoteRequestId);

      _loadQuotations();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quote moved to Archive'),
            backgroundColor: Colors.blueGrey,
          ),
        );
      }
    } catch (e) {
      print('Error cancelling quote: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to move to archive'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _restoreQuote(String quoteRequestId) async {
    try {
      await SupabaseService.client
          .from('quote_requests')
          .update({'status': 'pending'}).eq('id', quoteRequestId);

      _loadQuotations();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quote restored to Pending'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error restoring quote: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to restore quote'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteQuote(String quoteRequestId) async {
    // Prevent multiple simultaneous deletions
    if (_deletingQuote) return;

    try {
      // Show confirmation dialog first
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Permanently?'),
          content: const Text(
              'This will permanently delete this quote request. This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Set deleting state
      if (mounted) {
        setState(() {
          _deletingQuote = true;
        });
      }

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Deleting quotation...'),
              ],
            ),
            duration: Duration(seconds: 30), // Long duration for loading
          ),
        );
      }

      // Get user ID for RLS policy
      final user = SupabaseService.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final userData = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('email', user.email!)
          .maybeSingle();

      if (userData == null) {
        throw Exception('User not found in database');
      }

      // Delete from database with user_id for RLS
      final response = await SupabaseService.client
          .from('quote_requests')
          .delete()
          .eq('id', quoteRequestId)
          .eq('user_id', userData['id'])
          .select(); // Use select() to verify deletion

      print('Delete response: $response');

      // Verify deletion actually happened
      if (response.isEmpty) {
        throw Exception(
            'Quote request not found or you do not have permission to delete it');
      }

      // Only remove from UI if deletion succeeded
      if (mounted) {
        setState(() {
          _quotations.removeWhere((q) => q['id'] == quoteRequestId);
          _deletingQuote = false;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quotation permanently deleted'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error deleting quote: $e');

      // Reset deleting state
      if (mounted) {
        setState(() {
          _deletingQuote = false;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();

        // Show user-friendly error message
        String errorMessage = 'Failed to delete quotation';
        if (e.toString().contains('permission') ||
            e.toString().contains('not found')) {
          errorMessage =
              'You do not have permission to delete this quotation or it does not exist';
        } else if (e.toString().contains('network') ||
            e.toString().contains('connection')) {
          errorMessage =
              'Network error. Please check your connection and try again';
        } else {
          errorMessage = 'Failed to delete quotation: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _deleteSelectedQuotes() async {
    if (_selectedQuotationIds.isEmpty || _deletingQuote) return;

    final count = _selectedQuotationIds.length;

    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Selected Quotations?'),
          content: Text(
              'This will permanently delete $count quotation(s). This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete All'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Set deleting state
      if (mounted) {
        setState(() {
          _deletingQuote = true;
        });
      }

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text('Deleting $count quotation(s)...'),
              ],
            ),
            duration: const Duration(seconds: 30), // Long duration for loading
          ),
        );
      }

      // Get user ID for RLS
      final user = SupabaseService.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final userData = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('email', user.email!)
          .maybeSingle();

      if (userData == null) {
        throw Exception('User not found');
      }

      final idsToDelete = Set<String>.from(_selectedQuotationIds);
      final successfullyDeleted = <String>[];
      final failedDeletions = <String>[];

      // Delete all selected quotations from database
      for (final id in idsToDelete) {
        try {
          final response = await SupabaseService.client
              .from('quote_requests')
              .delete()
              .eq('id', id)
              .eq('user_id', userData['id'])
              .select();

          // Verify deletion succeeded
          if (response.isNotEmpty) {
            successfullyDeleted.add(id);
          } else {
            failedDeletions.add(id);
          }
        } catch (e) {
          print('Error deleting quote $id: $e');
          failedDeletions.add(id);
        }
      }

      // Only remove successfully deleted items from UI
      if (mounted) {
        setState(() {
          _quotations.removeWhere((q) => successfullyDeleted.contains(q['id']));
          _selectedQuotationIds.clear();
          _isSelectionMode = false;
          _deletingQuote = false;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();

        if (failedDeletions.isEmpty) {
          // All deletions succeeded
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$count quotation(s) permanently deleted'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else if (successfullyDeleted.isNotEmpty) {
          // Partial success
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${successfullyDeleted.length} quotation(s) deleted. ${failedDeletions.length} failed.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          // All deletions failed
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Failed to delete ${failedDeletions.length} quotation(s)'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('Error deleting selected quotes: $e');

      // Reset deleting state
      if (mounted) {
        setState(() {
          _deletingQuote = false;
          _selectedQuotationIds.clear();
          _isSelectionMode = false;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();

        // Show user-friendly error message
        String errorMessage = 'Failed to delete quotations';
        if (e.toString().contains('permission') ||
            e.toString().contains('not found')) {
          errorMessage =
              'You do not have permission to delete some quotations or they do not exist';
        } else if (e.toString().contains('network') ||
            e.toString().contains('connection')) {
          errorMessage =
              'Network error. Please check your connection and try again';
        } else {
          errorMessage = 'Failed to delete quotations: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedQuotationIds.clear();
      }
    });
  }

  void _toggleQuotationSelection(String id) {
    setState(() {
      if (_selectedQuotationIds.contains(id)) {
        _selectedQuotationIds.remove(id);
      } else {
        _selectedQuotationIds.add(id);
      }
    });
  }

  // Maps UI filter label → matching DB status values
  bool _matchesFilter(Map<String, dynamic> quote, String filter) {
    final status = quote['status']?.toString().toLowerCase() ?? '';
    switch (filter) {
      case 'All':
        return status != 'archived' && status != 'cancelled';
      case 'Pending':
        return status == 'pending';
      case 'Quoted':
        return status == 'quoted' || status == 'quotation_sent';
      case 'Accepted':
        return status == 'accepted' ||
            status == 'quotation_accepted' ||
            status == 'payment_details_sent' ||
            status == 'order_placed';
      case 'Rejected':
        return status == 'rejected';
      case 'Archive':
        return status == 'archived' || status == 'cancelled';
      default:
        return status == filter.toLowerCase();
    }
  }

  List<Map<String, dynamic>> get _filteredQuotes {
    return _quotations
        .where((q) => _matchesFilter(q, _selectedFilter))
        .toList();
  }

  String _formatDate(dynamic dateString) {
    try {
      if (dateString == null) return 'N/A';
      final date = DateTime.parse(dateString.toString());
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'approved':
      case 'order_placed':
        return const Color(0xFF10B981);
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'quoted':
      case 'quotation_sent':
        return const Color(0xFF3B82F6);
      case 'accepted':
      case 'quotation_accepted':
      case 'payment_details_sent':
        return const Color(0xFF8B5CF6);
      case 'cancelled':
        return const Color(0xFF6B7280);
      case 'expired':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF6B7280);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: RefreshIndicator(
            onRefresh: _manualRefresh,
            child: CustomScrollView(
              slivers: [
                // Header - Replaced with 3D Premium Hero Card
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    height: 180,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(24),
                      image: const DecorationImage(
                        image: AssetImage('assets/images/3d_quotes_hero_v3.png'),
                        fit: BoxFit.cover,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Glassy action bar at the bottom
                        Positioned(
                          top: 12,
                          left: 12,
                          right: 12,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            'Quotations\n& Estimates',
                                            style: TextStyle(
                                              fontSize: 16,
                                              height: 1.1,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF1E293B),
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${_filteredQuotes.length} quotes loaded',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF4F46E5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Actions
                                    if (_isSelectionMode) ...[
                                      if (_selectedQuotationIds.isNotEmpty)
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: _deleteSelectedQuotes,
                                          icon: const Icon(Icons.delete_forever, size: 22),
                                          tooltip: 'Delete Selected (${_selectedQuotationIds.length})',
                                          color: Colors.red,
                                        ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: _toggleSelectionMode,
                                        icon: const Icon(Icons.close, size: 22),
                                        tooltip: 'Cancel Selection',
                                        color: Colors.grey[600],
                                      ),
                                    ] else
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: _toggleSelectionMode,
                                        icon: const Icon(Icons.checklist, size: 22),
                                        tooltip: 'Select Multiple',
                                        color: const Color(0xFF4F46E5),
                                      ),
                                    const SizedBox(width: 8),
                                    // Refresh Button
                                    if (_refreshingQuotations)
                                      const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                                        ),
                                      )
                                    else
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: _manualRefresh,
                                        icon: const Icon(Icons.refresh, color: Color(0xFF4F46E5), size: 22),
                                        tooltip: 'Refresh quotes',
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Business Credit widget (moved from Home screen)
                SliverToBoxAdapter(
                  child: BusinessCreditWidgetV2(key: _creditWidgetKey),
                ),

                // Filter Tabs (Sticky)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyFilterDelegate(
                    minHeight: 68,
                    maxHeight: 68,
                    child: Container(
                      color: const Color(0xFFF8FAFC), // Match background color to prevent scrolling overlap
                      child: Container(
                        height: 52,
                        margin: const EdgeInsets.only(top: 8, bottom: 8),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: _filterOptions.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final filter = _filterOptions[index];
                            final isSelected = _selectedFilter == filter;
                            final count = _quotations.where((q) => _matchesFilter(q, filter)).length;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedFilter = filter;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF4F46E5) : Colors.white,
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF4F46E5) : Colors.grey[200]!,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      filter,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (count > 0) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isSelected ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          count.toString(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: isSelected ? Colors.white : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // Quote Request Cart Section
                Consumer<QuoteRequestCartService>(
                  builder: (context, quoteRequestCart, child) {
                    if (quoteRequestCart.isEmpty) {
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }

                    return SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFDE68A), width: 1.5), // Yellow/Orange accent border
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Compact Header
                            Row(
                              children: [
                                const Icon(
                                  Icons.shopping_cart_outlined,
                                  color: Color(0xFFF59E0B),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Quote Request Cart',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF92400E),
                                        ),
                                      ),
                                      Text(
                                        '${quoteRequestCart.itemCount} products • ${quoteRequestCart.totalItems} total items',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFFF59E0B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    '${quoteRequestCart.totalItems}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Compact Cart Items
                            ...quoteRequestCart.items.entries.map((entry) {
                              final item = entry.value;
                              final key = entry.key;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFFFFEDD5)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Left side - Product info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Product name and brand in one line
                                          Row(
                                            children: [
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  item.product.productName,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF1E293B),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ),
                                              if (item.product.brandId != null)
                                                Expanded(
                                                  flex: 1,
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFFF1F5F9),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Text(
                                                      item.product.brandId!,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            Color(0xFF64748B),
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),

                                          const SizedBox(height: 6),

                                          // Quality option and quantity in one row
                                          Row(
                                            children: [
                                              if (item.qualityOptionId !=
                                                      null &&
                                                  item.qualityOptionId !=
                                                      'default')
                                                Flexible(
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFFFEF3C7),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Text(
                                                      item.qualityOptionName,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            Color(0xFF92400E),
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                              if (item.qualityOptionId !=
                                                      null &&
                                                  item.qualityOptionId !=
                                                      'default')
                                                const SizedBox(width: 8),
                                              Flexible(
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFF0F9FF),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                    border: Border.all(
                                                        color: const Color(
                                                            0xFF0EA5E9)),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons
                                                            .inventory_2_outlined,
                                                        size: 12,
                                                        color:
                                                            Color(0xFF0EA5E9),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Flexible(
                                                        child: Text(
                                                          '${item.quantity} ${item.product.unit ?? 'units'}',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Color(
                                                                0xFF0EA5E9),
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(width: 10),

                                    // Right side - Controls
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Quantity controls
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(
                                                  minWidth: 24, minHeight: 24),
                                              icon: const Icon(
                                                  Icons.remove_circle_outline,
                                                  size: 18),
                                              color: Colors.red[400],
                                              onPressed: () {
                                                if (item.quantity > 1) {
                                                  quoteRequestCart
                                                      .updateQuantity(
                                                    key,
                                                    item.quantity - 1,
                                                  );
                                                } else {
                                                  quoteRequestCart
                                                      .removeItem(key);
                                                }
                                              },
                                            ),
                                            Container(
                                              width: 24,
                                              alignment: Alignment.center,
                                              child: Text(
                                                '${item.quantity}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF1E293B),
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(
                                                  minWidth: 24, minHeight: 24),
                                              icon: const Icon(
                                                  Icons.add_circle_outline,
                                                  size: 18),
                                              color: Colors.green[600],
                                              onPressed: () {
                                                quoteRequestCart.updateQuantity(
                                                  key,
                                                  item.quantity + 1,
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }),

                            const SizedBox(height: 8),

                            // Compact Summary
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(6),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'Total Products:',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF475569),
                                              ),
                                            ),
                                            Text(
                                              '${quoteRequestCart.itemCount}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1E293B),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'Total Items:',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF475569),
                                              ),
                                            ),
                                            Text(
                                              '${quoteRequestCart.totalItems}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1E293B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 12,
                                          color: Color(0xFF166534),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          '24-48h',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF166534),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _submittingQuote
                                    ? null
                                    : () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const QuoteRequestCartScreen(),
                                          ),
                                        );
                                      },
                                icon: _submittingQuote
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : const Icon(Icons.send, size: 16),
                                label: Text(
                                  _submittingQuote
                                      ? 'Submitting...'
                                      : 'Submit Quote Request',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF59E0B),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  disabledBackgroundColor:
                                      const Color(0xFFF59E0B).withValues(alpha: 0.5),
                                  disabledForegroundColor:
                                      Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // Loading State
                if (_loadingQuotations)
                  const SliverFillRemaining(
                    child: AppLoadingState(),
                  )
                else
                  // Quotes List
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20,
                        120), // Increased bottom padding for navigation
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final quotation = _filteredQuotes[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildQuoteCard(quotation, index),
                          );
                        },
                        childCount: _filteredQuotes.length,
                      ),
                    ),
                  ),

                // Empty State - Only show when cart is empty
                Consumer<QuoteRequestCartService>(
                  builder: (context, quoteRequestCart, child) {
                    if (!_loadingQuotations &&
                        _filteredQuotes.isEmpty &&
                        quoteRequestCart.isEmpty) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Center(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0F4FF),
                                      borderRadius: BorderRadius.circular(60),
                                    ),
                                    child: const Icon(
                                      Icons.description_outlined,
                                      size: 60,
                                      color: Color(0xFF667EEA),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'No Quotations Yet',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Start exploring our products and request quotes for your construction needs',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      // Switch to home tab using callback
                                      widget.onSwitchToHome?.call();
                                    },
                                    icon: const Icon(Icons.search),
                                    label: const Text('Browse Products'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF667EEA),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 32, vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  },
                ),

                // Bottom Spacing
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuoteCard(Map<String, dynamic> quotation, int index) {
    final statusColor = _getStatusColor(quotation['status']);
    final isQuoteRequest =
        quotation['quotes'] == null || quotation['quotes'].isEmpty;
    final isOldSystem = quotation['system'] == 'old';

    return GestureDetector(
      onTap: _isSelectionMode
          ? () => _toggleQuotationSelection(quotation['id'])
          : () => _showQuoteDetails(quotation),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300 + (index * 50)),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Selection checkbox
                  if (_isSelectionMode) ...[
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _selectedQuotationIds.contains(quotation['id']),
                        onChanged: (bool? value) {
                          _toggleQuotationSelection(quotation['id']);
                        },
                        activeColor: const Color(0xFF4F46E5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],

                  // Minimal Dot Status Indicator
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isOldSystem
                            ? 'Legacy Quote'
                            : (isQuoteRequest
                                ? (quotation['status'] == 'rejected' ||
                                        quotation['status'] == 'cancelled' ||
                                        quotation['status'] == 'archived'
                                    ? 'Archived Request'
                                    : 'Quote Request')
                                : 'Quote Response'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Minimal Reference ID
                  if (!_isSelectionMode)
                    Text(
                      '#${quotation['id'].toString().substring(0, 8).toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Product Info Title and Image Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image (if available)
                  Builder(
                    builder: (context) {
                      String? imageUrl;
                      if (quotation['quote_request_items'] != null &&
                          (quotation['quote_request_items'] as List).isNotEmpty) {
                        final items = quotation['quote_request_items'] as List;
                        for (var item in items) {
                          if (item['products'] != null &&
                              item['products']['photos'] != null) {
                            final photos = item['products']['photos'];
                            if (photos is List && photos.isNotEmpty) {
                              imageUrl = photos.first.toString();
                              break;
                            }
                          }
                        }
                      }
                      if (imageUrl != null && imageUrl.isNotEmpty) {
                        return Container(
                          width: 48,
                          height: 48,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.image_not_supported,
                                    color: Colors.grey, size: 20);
                              },
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOldSystem
                              ? (quotation['product_id'] ?? 'Product ID')
                              : (quotation['product_name'] ?? 'Product Name'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                            height: 1.3,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
              const SizedBox(height: 4),
              // Soft status text without pill
              Text(
                'Status: ${quotation['status'] == 'cancelled' || quotation['status'] == 'archived' ? 'Archived' : (quotation['status'] ?? 'pending').toString().replaceAll('_', ' ')}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              if (quotation['status']?.toLowerCase() == 'accepted') ...[
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle,
                          size: 16, color: Color(0xFF059669)),
                      SizedBox(width: 6),
                      Text(
                        'Payment Successful',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Quote Summary
              if (isOldSystem) ...[
                if (quotation['price'] != null)
                  _buildInfoItem(
                    'Price',
                    '₹${quotation['price']}',
                    Icons.currency_rupee,
                  ),
                if (quotation['price'] == null)
                  _buildInfoItem(
                    'Price',
                    'On Request',
                    Icons.currency_rupee,
                  ),
                _buildInfoItem(
                  'Notes',
                  quotation['notes'] ?? 'No notes',
                  Icons.note_outlined,
                ),
              ] else if (isQuoteRequest) ...[
                if (quotation['quote_request_items'] != null &&
                    quotation['quote_request_items'].isNotEmpty) ...[
                  ...(quotation['quote_request_items'] as List)
                      .map<Widget>((item) => _buildItemRowWithImage(
                            item,
                            defaultProductName: quotation['product_name'],
                          )),
                ] else ...[
                  _buildItemRowWithImage(
                    {
                      'product_name': quotation['product_name'] ?? 'Product',
                      'quality_option_name': 'Pending review',
                      'quantity': 1,
                    },
                  ),
                ],
              ] else ...[
                if (quotation['quotes'] != null &&
                    quotation['quotes'].isNotEmpty) ...[
                  if (quotation['quotes'][0]['quote_items'] != null) ...[
                    ...(quotation['quotes'][0]['quote_items'] as List).map<Widget>((item) {
                      Map<String, dynamic> originalItem = {};
                      if (quotation['quote_request_items'] != null) {
                        try {
                          originalItem = (quotation['quote_request_items'] as List).firstWhere(
                            (reqItem) => reqItem['quality_option_id'] == item['quality_option_id'],
                            orElse: () => {},
                          );
                        } catch (_) {}
                      }
                      final Map<String, dynamic> displayItem = Map<String, dynamic>.from(item as Map);
                      if (originalItem['products'] != null) {
                        displayItem['products'] = originalItem['products'];
                      }
                      return _buildItemRowWithImage(
                        displayItem,
                        defaultProductName: quotation['product_name'],
                        price: (item['unit_price'] as num?)?.toDouble(),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                  _buildInfoItem(
                    'Total Amount',
                    '₹${(quotation['quotes'][0]['total_amount'] ?? 0).toStringAsFixed(2)}',
                    Icons.currency_rupee,
                  ),
                  _buildInfoItem(
                    'Validity',
                    '${quotation['quotes'][0]['validity_days'] ?? 7} days',
                    Icons.calendar_today_outlined,
                  ),
                ],
              ],

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      'Request Date',
                      _formatDate(quotation['created_at']),
                      Icons.calendar_today_outlined,
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      'System',
                      isOldSystem ? 'Legacy' : 'New',
                      isOldSystem
                          ? Icons.history_outlined
                          : Icons.new_releases_outlined,
                    ),
                  ),
                ],
              ),

              // Action Row - Wrapped to prevent tap propagation to parent GestureDetector
              const Divider(height: 24, color: Color(0xFFF1F5F9)),
              GestureDetector(
                onTap: () {},
                child: Row(
                  children: [
                    if (_selectedFilter == 'Archive' ||
                        quotation['status'] == 'cancelled' ||
                        quotation['status'] == 'archived') ...[
                      OutlinedButton(
                        onPressed: () => _restoreQuote(quotation['id']),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF10B981),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.restore, size: 14),
                            SizedBox(width: 4),
                            Text('Restore',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _deletingQuote
                            ? null
                            : () => _deleteQuote(quotation['id']),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_deletingQuote)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Color(0xFFEF4444)),
                              )
                            else
                              const Icon(Icons.delete_forever, size: 14),
                            const SizedBox(width: 4),
                            const Text('Delete',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ] else if (quotation['status'] == 'pending') ...[
                      OutlinedButton(
                        onPressed: _deletingQuote
                            ? null
                            : () => _cancelQuote(quotation['id']),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFF59E0B),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cancel_outlined, size: 14),
                            SizedBox(width: 4),
                            Text('Cancel',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ] else ...[
                      OutlinedButton(
                        onPressed: _deletingQuote
                            ? null
                            : () => _deleteQuote(quotation['id']),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_deletingQuote)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Color(0xFFEF4444)),
                              )
                            else
                              const Icon(Icons.delete_forever, size: 14),
                            const SizedBox(width: 4),
                            const Text('Delete',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    // Sharp Action Button
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _isSelectionMode
                          ? null
                          : () => _showQuoteDetails(quotation),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View Details',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemRowWithImage(Map<String, dynamic> item, {String? defaultProductName, double? price, int? quantity}) {
    final productName = item['product_name'] ?? defaultProductName ?? 'Product';
    final optionName = item['quality_option_name'] ?? 'Standard';
    final qty = quantity ?? item['quantity'] ?? 1;
    final unit = item['unit'] ?? 'units';
    final isAvailable = item['is_available'] != false;
    
    // Extract brand name if available
    String? brandName;
    if (item['brands'] != null && item['brands']['name'] != null) {
      brandName = item['brands']['name'];
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        brandName != null ? '$brandName - $productName - $optionName' : '$productName - $optionName',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isAvailable ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                          decoration: isAvailable ? TextDecoration.none : TextDecoration.lineThrough,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!isAvailable) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: const Text(
                          'Unavailable',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Qty: $qty $unit',
                      style: TextStyle(
                        fontSize: 12,
                        color: isAvailable ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (price != null)
                      Text(
                        isAvailable ? '₹${price.toStringAsFixed(2)}' : 'N/A',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isAvailable ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: const Color(0xFF64748B),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitTransactionId(String quoteRequestId) async {
    final txnId = await _showTransactionIdDialog(
      referenceId: quoteRequestId,
      isCreditPayment: false,
    );
    if (txnId == null) return;
    
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await SupabaseService.client.from('quote_requests').update({
        'transaction_id': txnId,
        'status': 'quotation_accepted'
      }).eq('id', quoteRequestId);
      _loadQuotations();
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction ID submitted successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch(e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving transaction ID: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showQuoteDetails(Map<String, dynamic> quote) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuoteDetailsSheet(
        quote: quote,
        onRefresh: _loadQuotations,
        onAcceptQuote: (id, {double? selectedAmount, List<Map<String, dynamic>>? selectedItems}) => _acceptQuote(id, selectedAmount: selectedAmount, selectedItems: selectedItems),
        onRejectQuote: _rejectQuote,
        onRetryEmail: _sendPaymentDetailsEmail,
        onSubmitTransactionId: _submitTransactionId,
      ),
    );
  }
}

class QuoteDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> quote;
  final VoidCallback onRefresh;
  final Function(String, {double? selectedAmount, List<Map<String, dynamic>>? selectedItems}) onAcceptQuote;
  final Function(String) onRejectQuote;
  final Function(String)? onRetryEmail;
  final Function(String)? onSubmitTransactionId;

  const QuoteDetailsSheet({
    super.key,
    required this.quote,
    required this.onRefresh,
    required this.onAcceptQuote,
    required this.onRejectQuote,
    this.onRetryEmail,
    this.onSubmitTransactionId,
  });

  @override
  State<QuoteDetailsSheet> createState() => _QuoteDetailsSheetState();
}

class _QuoteDetailsSheetState extends State<QuoteDetailsSheet> {
  final bool _showReRequestForm = false;
  final TextEditingController _reRequestMessageController =
      TextEditingController();

  // Track which brand index is selected for each product group
  // Key = product name (quality_option_name), Value = index in that group
  final Map<String, Set<int>> _selectedBrands = {};

  @override
  void dispose() {
    _reRequestMessageController.dispose();
    super.dispose();
  }

  // Check if quote has multiple brands needing selection
  bool _needsBrandSelection() {
    final quoteItems =
        widget.quote['quotes']?[0]?['quote_items'] as List? ?? [];
    if (quoteItems.isEmpty) return false;
    final grouped = <String, int>{};
    for (final it in quoteItems) {
      final name = (it['quality_option_name'] ?? 'Product').toString();
      grouped[name] = (grouped[name] ?? 0) + 1;
    }
    return grouped.values.any((count) => count > 1);
  }

  // Check if AT LEAST ONE product group has a brand selected
  bool _hasAnyBrandSelected() {
    final quoteItems =
        widget.quote['quotes']?[0]?['quote_items'] as List? ?? [];
    if (quoteItems.isEmpty) return false;
    
    // Check if user has explicitly selected at least one brand
    return _selectedBrands.values.any((set) => set.isNotEmpty);
  }

  // Get the selected items (one per product group) for pricing
  List<Map<String, dynamic>> _getSelectedItems() {
    final quoteItems =
        widget.quote['quotes']?[0]?['quote_items'] as List? ?? [];
    if (quoteItems.isEmpty) return [];

    // Group items
    final grouped = <String, List<Map<String, dynamic>>>{};
    final order = <String>[];
    for (final it in quoteItems) {
      final item = Map<String, dynamic>.from(it);
      final name = (item['quality_option_name'] ?? 'Product').toString();
      if (!grouped.containsKey(name)) {
        grouped[name] = [];
        order.add(name);
      }
      grouped[name]!.add(item);
    }

    final selected = <Map<String, dynamic>>[];
    for (final name in order) {
      final items = grouped[name]!;
      if (_selectedBrands.containsKey(name)) {
        final indices = _selectedBrands[name]!;
        for (final idx in indices) {
          if (idx < items.length) {
            final item = items[idx];
            if (item['is_available'] != false) {
              selected.add(item);
            }
          }
        }
      }
    }
    return selected;
  }

  // Calculate dynamic pricing from selected items
  Map<String, double> _calculateSelectedPricing() {
    final selectedItems = _getSelectedItems();
    double subtotal = 0;
    for (final item in selectedItems) {
      subtotal += (item['total_price'] ?? 0).toDouble();
    }
    // Use the original tax ratio to compute tax on new subtotal
    final origQuote = widget.quote['quotes'][0];
    final origSubtotal = (origQuote['subtotal'] ?? 1).toDouble();
    final origTax = (origQuote['tax_amount'] ?? 0).toDouble();
    final taxRate = origSubtotal > 0 ? origTax / origSubtotal : 0.18;
    final tax = subtotal * taxRate;
    final transport = (origQuote['transport_charges'] ?? 0).toDouble();
    return {
      'subtotal': subtotal,
      'tax': tax,
      'transport': transport,
      'total': subtotal + tax + transport,
    };
  }

  bool _hasTotalAmount() {
    if (widget.quote['quotes'] == null || widget.quote['quotes'].isEmpty) {
      return false;
    }
    final amount = widget.quote['quotes'][0]['total_amount'];
    return amount != null && (amount is num) && amount > 0;
  }

  String _formatDate(dynamic dateString) {
    try {
      if (dateString == null) return 'N/A';
      final date = DateTime.parse(dateString.toString());
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'approved':
      case 'order_placed':
        return const Color(0xFF10B981);
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'quoted':
      case 'quotation_sent':
        return const Color(0xFF3B82F6);
      case 'accepted':
      case 'quotation_accepted':
      case 'payment_details_sent':
        return const Color(0xFF8B5CF6);
      case 'cancelled':
        return const Color(0xFF6B7280);
      case 'expired':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'quotation_accepted':
      case 'payment_details_sent':
      case 'order_placed':
        return Icons.check_circle;
      case 'pending':
        return Icons.access_time;
      case 'quoted':
      case 'quotation_sent':
        return Icons.description;
      case 'rejected':
        return Icons.cancel;
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'expired':
        return Icons.schedule;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildRequestSummaryCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Request Summary',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow(
                'Request ID', widget.quote['id']?.substring(0, 8) ?? 'N/A'),
            const SizedBox(height: 12),
            _buildSummaryRow(
                'Request Date', _formatDate(widget.quote['created_at'])),
            const SizedBox(height: 12),
            _buildSummaryRow('Status', widget.quote['status'] ?? 'pending'),
            if (widget.quote['brand_name'] != null) ...[
              const SizedBox(height: 12),
              _buildSummaryRow('Supplier', widget.quote['brand_name']),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1E293B),
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBanner(String? status) {
    String message;
    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;

    switch (status?.toLowerCase()) {
      case 'pending':
        message =
            'Your quotation request has been submitted and is under review. Pricing details will be shared soon.';
        bgColor = const Color(0xFFFFF7ED);
        borderColor = const Color(0xFFFFEDD5);
        textColor = const Color(0xFF92400E);
        icon = Icons.schedule;
        break;
      case 'quoted':
      case 'quotation_sent':
        message = 'Quotation received. Please review the pricing details.';
        bgColor = const Color(0xFFF0F9FF);
        borderColor = const Color(0xFFBFDBFE);
        textColor = const Color(0xFF1E40AF);
        icon = Icons.check_circle_outline;
        break;
      case 'quotation_accepted':
        // Different banner depending on payment method
        if (widget.quote['payment_method'] == 'credit') {
          message =
              'Payment via business credit successful! Our team will verify and confirm your order shortly.';
          bgColor = const Color(0xFFF0FDF4);
          borderColor = const Color(0xFF86EFAC);
          textColor = const Color(0xFF166534);
          icon = Icons.check_circle;
        } else {
          message =
              'Quotation accepted. Bank transfer details have been sent to your email.';
          bgColor = const Color(0xFFEFF6FF);
          borderColor = const Color(0xFFBFDBFE);
          textColor = const Color(0xFF1E40AF);
          icon = Icons.mark_email_read;
        }
        break;
      case 'payment_details_sent':
        message =
            'Quotation accepted. Payment details have been emailed to you.';
        bgColor = const Color(0xFFF3E8FF);
        borderColor = const Color(0xFFD8B4FE);
        textColor = const Color(0xFF6B21A8);
        icon = Icons.email_outlined;
        break;
      case 'order_placed':
        message = 'Order Confirmed! The seller has verified your payment.';
        bgColor = const Color(0xFFDCFCE7);
        borderColor = const Color(0xFF86EFAC);
        textColor = const Color(0xFF166534);
        icon = Icons.verified;
        break;
      case 'cancelled':
      case 'rejected':
        message = 'This quotation request has been cancelled.';
        bgColor = const Color(0xFFFEF2F2);
        borderColor = const Color(0xFFFECACA);
        textColor = const Color(0xFF991B1B);
        icon = Icons.cancel_outlined;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final status = widget.quote['status']?.toLowerCase();
    final isQuoteRequest =
        widget.quote['quotes'] == null || widget.quote['quotes'].isEmpty;

    if (isQuoteRequest && status == 'pending') {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () async {
            // Show cancel confirmation
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Cancel Request?'),
                content: const Text(
                    'Are you sure you want to cancel this quotation request?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('No'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Yes, Cancel'),
                  ),
                ],
              ),
            );

            if (confirmed == true) {
              try {
                // Update quote request status to rejected instead of cancelled
                // since 'cancelled' is not allowed by the database constraint
                await SupabaseService.client.from('quote_requests').update(
                    {'status': 'rejected'}).eq('id', widget.quote['id']);

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Quote request cancelled successfully'),
                    backgroundColor: Colors.green,
                  ),
                );

                // Refresh the parent screen's quotation list
                widget.onRefresh();
              } catch (e) {
                // Show detailed error for debugging
                String errorMessage = 'Error cancelling quote request';
                if (e.toString().contains('constraint')) {
                  errorMessage =
                      'Status change not allowed. Please contact support.';
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(errorMessage),
                    backgroundColor: Colors.red,
                  ),
                );

                // Log the full error for debugging
                print('Cancel quote request error: $e');
              }
            }
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: const BorderSide(color: Color(0xFFEF4444)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Cancel Request',
            style: TextStyle(
              color: Color(0xFFEF4444),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    } else if ((status == 'quoted' || status == 'quotation_sent') &&
        widget.quote['quotes'] != null &&
        widget.quote['quotes'].isNotEmpty) {
      // If brand selection is needed but not complete, show a prompt
      if (_needsBrandSelection() && !_hasAnyBrandSelected()) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.touch_app_rounded,
                  size: 20, color: Color(0xFFD97706)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Please select a brand for each product above to see pricing and proceed.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Calculate the selected amount and selected items if brand selection was used
                    double? selectedAmount;
                    List<Map<String, dynamic>>? selectedItems;
                    if (!_needsBrandSelection() || _hasAnyBrandSelected()) {
                      final pricing = _calculateSelectedPricing();
                      selectedAmount = pricing['total'];
                      selectedItems = _getSelectedItems();
                    }
                    Navigator.pop(context);
                    widget.onAcceptQuote(widget.quote['id'],
                        selectedAmount: selectedAmount,
                        selectedItems: selectedItems);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _hasTotalAmount() ? 'Pay & Accept' : 'Accept Quote',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onRejectQuote(widget.quote['id']);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Reject Quote',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    } else if (status == 'quotation_accepted' ||
        status == 'payment_details_sent') {
      // Check if paid via credit — show simple confirmation, not the bank-transfer email widget
      final paymentMethod = widget.quote['payment_method']?.toString();
      final isPaidByCredit = paymentMethod == 'credit';

      if (isPaidByCredit) {
        // Credit payment — show confirmation message only
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle,
                      color: Color(0xFF16A34A), size: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment via Credit Successful!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF166534),
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your payment has been deducted from your business credit. '
                          'Our team will verify and place your order shortly.',
                          style:
                              TextStyle(color: Color(0xFF166534), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.hourglass_top_rounded,
                      color: Color(0xFFD97706), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Our team is verifying your order...',
                      style: TextStyle(
                          color: Color(0xFF92400E),
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }

      // Bank transfer / other payment — show email widget + resend button
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Status banner ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.mark_email_read,
                        color: Color(0xFF3B82F6), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Payment Details Sent!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1D4ED8),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  'We have sent the bank payment details to your registered email address. '
                  'Please transfer the exact amount and reply to the email with your payment receipt. '
                  'Your order will be confirmed once our team verifies the payment.',
                  style: TextStyle(color: Color(0xFF1E40AF), fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── Awaiting verification note ───────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.hourglass_top_rounded,
                    color: Color(0xFFD97706), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Awaiting payment verification by our team...',
                        style: TextStyle(
                            color: Color(0xFF92400E),
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                      if (widget.quote['transaction_id'] != null && widget.quote['transaction_id'].toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Transaction ID: ${widget.quote['transaction_id']}',
                          style: const TextStyle(
                              color: Color(0xFF92400E),
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── Submit Transaction ID Button ─────────────────────────────────
          if (widget.onSubmitTransactionId != null && status != 'quotation_accepted' && (widget.quote['transaction_id']?.toString().isEmpty ?? true)) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onSubmitTransactionId!(widget.quote['id']);
                },
                icon: const Icon(Icons.receipt_long, size: 18),
                label: const Text(
                  'Submit Transaction ID',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // ── Resend button ────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                if (widget.onRetryEmail != null) {
                  widget.onRetryEmail!(widget.quote['id']);
                }
              },
              icon: const Icon(Icons.send, size: 18, color: Color(0xFF8B5CF6)),
              label: const Text(
                'Resend Payment Details Email',
                style: TextStyle(
                    color: Color(0xFF8B5CF6), fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFF8B5CF6)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink(); // No buttons for cancelled/other statuses
  }

  // ── Brand Comparison: group quote_items by product name ──────────────
  // â”€â”€ Brand Comparison: group quote_items by product name â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildComparisonQuotedItems() {
    final quoteItems =
        widget.quote['quotes'][0]['quote_items'] as List? ?? [];
    final requestItems =
        widget.quote['quote_request_items'] as List? ?? [];

    if (quoteItems.isEmpty) return const SizedBox.shrink();

    final isQuoted = widget.quote['status']?.toLowerCase() == 'quoted' ||
        widget.quote['status']?.toLowerCase() == 'quotation_sent';

    // Enrich each item with resolved brand name
    final enriched = <Map<String, dynamic>>[];
    for (int i = 0; i < quoteItems.length; i++) {
      final item = Map<String, dynamic>.from(quoteItems[i]);
      String? brandName = item['brand_name'];

      if (brandName == null && i < requestItems.length) {
        final ri = requestItems[i];
        brandName = ri['brands']?['name'] ??
            ri['brand_name'] ??
            ri['products']?['brands']?['name'];
      }

      String unitLabel = 'Pc Price';
      if (i < requestItems.length) {
        final ri = requestItems[i];
        final unit = ri['unit'];
        if (unit != null && unit.toString().isNotEmpty) {
          final u = unit.toString();
          unitLabel = '${u[0].toUpperCase()}${u.substring(1)} Price';
        }
      }

      enriched.add({
        ...item,
        '_brand': brandName ?? 'Brand ${i + 1}',
        '_unitLabel': unitLabel,
        if (i < requestItems.length) '_ri': requestItems[i],
      });
    }

    // Group by quality_option_name
    final grouped = <String, List<Map<String, dynamic>>>{};
    final order = <String>[];
    for (final it in enriched) {
      final name = (it['quality_option_name'] ?? 'Product').toString();
      if (!grouped.containsKey(name)) {
        grouped[name] = [];
        order.add(name);
      }
      grouped[name]!.add(it);
    }

    // Brand-colour palette for visual distinction
    const brandColors = [
      Color(0xFF10B981),
      Color(0xFF3B82F6),
      Color(0xFF8B5CF6),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF06B6D4),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4F46E5).withValues(alpha: 0.05),
            const Color(0xFF7C3AED).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E7FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // â”€â”€ Header â”€â”€
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.compare_arrows_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quoted Items',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      isQuoted && _needsBrandSelection()
                          ? 'Tap to select a brand per product'
                          : 'Side-by-side brand comparison',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${quoteItems.length} items',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // â”€â”€ One card per product â”€â”€
          ...order.map((productName) {
            final brands = grouped[productName]!;
            final hasMultiple = brands.length > 1;
            final selectedIndices = _selectedBrands[productName] ?? <int>{};
            final firstBrand = brands.isNotEmpty ? brands.first : null;
            final ri = firstBrand != null ? firstBrand['_ri'] : null;
            final productMap = ri != null ? ri['products'] : null;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product name header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF4F46E5),
                                Color(0xFF7C3AED),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.inventory_2_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  productName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                              if (productMap != null) ...[
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () {
                                    try {
                                      final product = ProductModel.fromJson(Map<String, dynamic>.from(productMap));
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ProductDetailsScreen(product: product),
                                        ),
                                      );
                                    } catch (e) {
                                      print('Error opening product details: $e');
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.launch_rounded,
                                      size: 14,
                                      color: Color(0xFF4F46E5),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (selectedIndices.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle,
                                    size: 12,
                                    color: Color(0xFF10B981)),
                                SizedBox(width: 4),
                                Text(
                                  'Selected',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (isQuoted)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.touch_app_rounded,
                                    size: 12,
                                    color: Color(0xFFF59E0B)),
                                const SizedBox(width: 4),
                                Text(
                                  'Tap to select',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFF59E0B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Brand columns - horizontally scrollable
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children:
                              brands.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final b = entry.value;
                            final bName = b['_brand'] as String;
                            final bColor =
                                brandColors[idx % brandColors.length];
                            final isLast =
                                idx == brands.length - 1;
                            final isSelected = selectedIndices.contains(idx);
                            final isAvailable = b['is_available'] != false;
                            final canSelect = isQuoted && isAvailable; // Allow selection even if only 1 brand, but must be available

                            // Removed dimming for multiple selection
                            final isDimmed = false;

                            return GestureDetector(
                              onTap: canSelect
                                  ? () {
                                      setState(() {
                                        _selectedBrands.putIfAbsent(productName, () => <int>{});
                                        if (isSelected) {
                                          _selectedBrands[productName]!.remove(idx);
                                        } else {
                                          _selectedBrands[productName]!.add(idx);
                                        }
                                      });
                                    }
                                  : null,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: isDimmed ? 0.4 : 1.0,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 140,
                                  margin: EdgeInsets.only(
                                      right: isLast ? 0 : 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: !isAvailable
                                        ? const Color(0xFFF1F5F9)
                                        : isSelected
                                            ? bColor.withValues(alpha: 0.08)
                                            : bColor.withValues(alpha: 0.04),
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    border: Border.all(
                                      color: !isAvailable
                                          ? const Color(0xFFCBD5E1)
                                          : isSelected
                                              ? bColor
                                              : bColor.withValues(alpha: 0.25),
                                      width: isSelected ? 2.5 : 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      // Selection indicator
                                      if (canSelect) ...[
                                        Icon(
                                          isSelected
                                              ? Icons.check_box_rounded
                                              : Icons.check_box_outline_blank_rounded,
                                          size: 22,
                                          color: isSelected
                                              ? bColor
                                              : const Color(0xFFCBD5E1),
                                        ),
                                        const SizedBox(height: 6),
                                      ] else if (!isAvailable) ...[
                                        const Icon(
                                          Icons.block_rounded,
                                          size: 22,
                                          color: Color(0xFFEF4444),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'Unavailable',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFEF4444),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                      ],
                                      // Brand badge
                                      Container(
                                        width: double.infinity,
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 5),
                                        decoration: BoxDecoration(
                                          color: !isAvailable
                                              ? const Color(0xFFE2E8F0)
                                              : bColor.withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                                !isAvailable
                                                    ? Icons.remove_circle_outline_rounded
                                                    : Icons.verified_rounded,
                                                size: 13,
                                                color: !isAvailable
                                                    ? const Color(0xFF64748B)
                                                    : bColor),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                bName,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                  color: !isAvailable
                                                      ? const Color(0xFF64748B)
                                                      : bColor,
                                                ),
                                                overflow: TextOverflow
                                                    .ellipsis,
                                                textAlign:
                                                    TextAlign.center,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      // Qty
                                      _buildComparisonMetric(
                                        Icons.numbers_rounded,
                                        'Qty',
                                        '${b['quantity']}',
                                      ),
                                      const SizedBox(height: 6),

                                      // Unit price
                                      _buildComparisonMetric(
                                        Icons.sell_rounded,
                                        b['_unitLabel'] ?? 'Pc Price',
                                        isAvailable
                                            ? '\u20B9${(b['unit_price'] ?? 0).toStringAsFixed(0)}'
                                            : 'N/A',
                                      ),
                                      const SizedBox(height: 8),

                                      // Total
                                      const Spacer(),
                                      Container(
                                        width: double.infinity,
                                        padding:
                                            const EdgeInsets.symmetric(
                                                vertical: 8,
                                                horizontal: 8),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end:
                                                Alignment.bottomRight,
                                            colors: isAvailable
                                                ? [
                                                    const Color(0xFF10B981)
                                                        .withValues(alpha: 0.1),
                                                    const Color(0xFF059669)
                                                        .withValues(alpha: 0.1),
                                                  ]
                                                : [
                                                    const Color(0xFF64748B)
                                                        .withValues(alpha: 0.1),
                                                    const Color(0xFF475569)
                                                        .withValues(alpha: 0.1),
                                                  ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              'Total',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight:
                                                    FontWeight.w500,
                                                color: isAvailable
                                                    ? const Color(0xFF059669)
                                                    : const Color(0xFF64748B),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              isAvailable
                                                  ? '\u20B9${(b['total_price'] ?? 0).toStringAsFixed(0)}'
                                                  : 'N/A',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight:
                                                    FontWeight.w800,
                                                color: isAvailable
                                                    ? const Color(0xFF059669)
                                                    : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Selection progress indicator
          if (isQuoted && _needsBrandSelection()) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _hasAnyBrandSelected()
                    ? const Color(0xFF10B981).withValues(alpha: 0.08)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _hasAnyBrandSelected()
                      ? const Color(0xFF10B981).withValues(alpha: 0.3)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _hasAnyBrandSelected()
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    size: 18,
                    color: _hasAnyBrandSelected()
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _hasAnyBrandSelected()
                          ? 'Review pricing for selected items below.'
                          : 'Select at least one brand/product to see final pricing',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _hasAnyBrandSelected()
                            ? const Color(0xFF059669)
                            : const Color(0xFFD97706),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComparisonMetric(
      IconData icon, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: const Color(0xFF94A3B8)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(widget.quote['status']);
    final statusIcon = _getStatusIcon(widget.quote['status'] ?? 'pending');
    final isQuoteRequest =
        widget.quote['quotes'] == null || widget.quote['quotes'].isEmpty;
    final isQuotedButNoData =
        widget.quote['status'] == 'quoted' && isQuoteRequest;
    final isOldSystem = widget.quote['system'] == 'old';

    // Debug prints
    print('QuoteDetailsSheet Debug:');
    print('Status: ${widget.quote['status']}');
    print('Quotes: ${widget.quote['quotes']}');
    print('isQuoteRequest: $isQuoteRequest');
    print('isQuotedButNoData: $isQuotedButNoData');
    print('isOldSystem: $isOldSystem');

    return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 40,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Premium Handle
              Container(
                width: 48,
                height: 5,
                margin: const EdgeInsets.only(top: 16, bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),

              // Clean Header
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: const Color(0xFFE2E8F0).withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isOldSystem
                                ? 'Legacy Quote'
                                : (isQuoteRequest
                                    ? 'Quote Request'
                                    : 'Quote Response'),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Reference ID: #${widget.quote['id'].toString().substring(0, 8).toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            statusIcon,
                            size: 14,
                            color: statusColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            (widget.quote['status'] ?? 'pending').toString().replaceAll('_', ' '),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                              letterSpacing: 0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(
                      left: 20, top: 20, right: 20, bottom: 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Request Summary Card
                      if (!isOldSystem) ...[
                        _buildRequestSummaryCard(),
                        const SizedBox(height: 20),
                      ],

                      // Status Banner
                      if (!isOldSystem) ...[
                        _buildStatusBanner(widget.quote['status']),
                        const SizedBox(height: 20),
                      ],

                      // Show message when quote is ready but data is missing
                      if (isQuotedButNoData) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.refresh,
                                      color: Colors.orange[700], size: 24),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Quote is Ready!',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Your quote has been generated by our team. Please refresh to see the pricing details.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.orange[600],
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    widget.onRefresh();
                                  },
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Refresh to See Quote'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange[600],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (isOldSystem) ...[
                        // Legacy Quote Information
                        _buildSection(
                          'Legacy Quote Information',
                          Icons.history_outlined,
                          [
                            _buildDetailRow('Product ID',
                                widget.quote['product_id'] ?? 'Unknown'),
                            _buildDetailRow(
                                'Status', widget.quote['status'] ?? 'pending'),
                            _buildDetailRow('Request Date',
                                _formatDate(widget.quote['created_at'])),
                            if (widget.quote['price'] != null)
                              _buildDetailRow(
                                  'Price', '₹${widget.quote['price']}'),
                            if (widget.quote['notes'] != null)
                              _buildDetailRow('Notes', widget.quote['notes']),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Migration Notice
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFEDD5)),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Color(0xFFF59E0B),
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'This is a legacy quotation from the old system. Consider migrating to the new quote request system for better features.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Quote Response (if available) - moved outside isQuoteRequest condition
                        if (widget.quote['quotes'] != null &&
                            widget.quote['quotes'].isNotEmpty) ...[
                          // Brand Comparison Quoted Items Section
                          _buildComparisonQuotedItems(),
                          const SizedBox(height: 16),

                          // Non-Returnable Warning Banner
                          Builder(builder: (ctx) {
                            final q0 = widget.quote['quotes']?[0] as Map<String, dynamic>?;
                            final isReturnable = (q0?['is_returnable'] as bool?) ?? true;
                            if (isReturnable) return const SizedBox.shrink();
                            return Container(
                              padding: const EdgeInsets.all(14),
                              margin: const EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFFFCA5A5)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.block_outlined,
                                      color: Color(0xFFDC2626), size: 22),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          'Non-Returnable Items',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF991B1B),
                                            fontSize: 14,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'The items in this quotation are non-returnable. Once the order is placed, the return option will not be available for these products.',
                                          style: TextStyle(
                                            color: Color(0xFFB91C1C),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 16),

                          // Dynamic Pricing Summary - only show when not needing selection OR all selected
                          if (!_needsBrandSelection() || _hasAnyBrandSelected()) ...[
                            Builder(
                              builder: (context) {
                                final pricing = _needsBrandSelection()
                                    ? _calculateSelectedPricing()
                                    : {
                                        'subtotal': (widget.quote['quotes'][0]['subtotal'] ?? 0).toDouble(),
                                        'tax': (widget.quote['quotes'][0]['tax_amount'] ?? 0).toDouble(),
                                        'transport': (widget.quote['quotes'][0]['transport_charges'] ?? 0).toDouble(),
                                        'total': (widget.quote['quotes'][0]['total_amount'] ?? 0).toDouble(),
                                      };
                                return Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFF1E293B), Color(0xFF334155)],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF1E293B).withValues(alpha: 0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      // Header
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Colors.white.withValues(alpha: 0.1),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Icon(
                                                Icons.receipt_rounded,
                                                color: Colors.white,
                                                size: 22,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Pricing Summary',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                if (_needsBrandSelection())
                                                  Text(
                                                    'Based on your selection',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w500,
                                                      color: Colors.white.withValues(alpha: 0.6),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Price Rows
                                      Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          children: [
                                            _buildModernPriceRow('Subtotal',
                                                '\u20B9${pricing['subtotal']!.toStringAsFixed(0)}',
                                                isSubtle: true),
                                            const SizedBox(height: 12),
                                            _buildModernPriceRow('Tax Amount',
                                                '\u20B9${pricing['tax']!.toStringAsFixed(0)}',
                                                isSubtle: true),
                                            const SizedBox(height: 12),
                                            _buildModernPriceRow('Transport Charges',
                                                '\u20B9${pricing['transport']!.toStringAsFixed(0)}',
                                                isSubtle: true),
                                            const SizedBox(height: 16),
                                            Container(
                                              height: 1,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.white.withValues(alpha: 0),
                                                    Colors.white.withValues(alpha: 0.3),
                                                    Colors.white.withValues(alpha: 0),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            // Grand Total
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Text(
                                                  'Grand Total',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 16, vertical: 8),
                                                  decoration: BoxDecoration(
                                                    gradient: const LinearGradient(
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                      colors: [
                                                        Color(0xFF10B981),
                                                        Color(0xFF059669)
                                                      ],
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    '\u20B9${pricing['total']!.toStringAsFixed(0)}',
                                                    style: const TextStyle(
                                                      fontSize: 22,
                                                      fontWeight: FontWeight.w800,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            // Validity Badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 14, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.schedule_rounded,
                                                    size: 16,
                                                    color: Color(0xFFFBBF24),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Valid for ${widget.quote['quotes'][0]['validity_days'] ?? 7} days',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFFFBBF24),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                          const SizedBox(height: 24),
                        ],

                        if (isQuoteRequest) ...[
                          // Quote Request Items - Beautifully Redesigned
                          if (widget.quote['quote_request_items'] != null &&
                              widget
                                  .quote['quote_request_items'].isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0xFF8B5CF6).withValues(alpha: 0.05),
                                    const Color(0xFFD946EF).withValues(alpha: 0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: const Color(0xFFE9D5FF)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Section Header
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF8B5CF6),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.list_alt_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Requested Items',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1E293B),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              'Items you requested for quotation',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF64748B),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF8B5CF6)
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '${(widget.quote['quote_request_items'] as List).length} items',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF8B5CF6),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Item Cards
                                  ...(widget.quote['quote_request_items']
                                          as List)
                                      .asMap()
                                      .entries
                                      .map<Widget>((entry) {
                                    final index = entry.key;
                                    final item = entry.value;

                                    // Get product name
                                    final productName = item['products']
                                            ?['name'] ??
                                        widget.quote['product_name'] ??
                                        'Product';

                                    // Get brand name - prioritize item's direct brand relationship
                                    String? brandName = item['brands']?[
                                            'name'] ?? // Item's direct brand_id relation
                                        item[
                                            'brand_name'] ?? // Item's brand_name field
                                        item['products']?['brands']?[
                                            'name']; // Product's brand (should NOT use this as fallback)

                                    // Get quality/size
                                    final qualityName =
                                        item['quality_option_name'] ??
                                            'Standard';

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withValues(alpha: 0.04),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        children: [
                                          // Item Header
                                          Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  const Color(0xFF8B5CF6)
                                                      .withValues(alpha: 0.08),
                                                  const Color(0xFFD946EF)
                                                      .withValues(alpha: 0.05),
                                                ],
                                              ),
                                              borderRadius:
                                                  const BorderRadius.only(
                                                topLeft: Radius.circular(16),
                                                topRight: Radius.circular(16),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                // Item Number Badge
                                                Container(
                                                  width: 36,
                                                  height: 36,
                                                  decoration: BoxDecoration(
                                                    gradient:
                                                        const LinearGradient(
                                                      begin: Alignment.topLeft,
                                                      end:
                                                          Alignment.bottomRight,
                                                      colors: [
                                                        Color(0xFF8B5CF6),
                                                        Color(0xFFD946EF)
                                                      ],
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      '${index + 1}',
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              productName,
                                                              style: const TextStyle(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight.w700,
                                                                color:
                                                                    Color(0xFF1E293B),
                                                              ),
                                                              maxLines: 1,
                                                              overflow: TextOverflow
                                                                  .ellipsis,
                                                            ),
                                                            if (brandName != null &&
                                                                brandName
                                                                    .isNotEmpty) ...[
                                                              const SizedBox(
                                                                  height: 4),
                                                              Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .symmetric(
                                                                        horizontal: 8,
                                                                        vertical: 3),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: const Color(
                                                                          0xFF10B981)
                                                                      .withValues(alpha: 
                                                                          0.1),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              6),
                                                                ),
                                                                child: Row(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    const Icon(
                                                                      Icons
                                                                          .verified_rounded,
                                                                      size: 12,
                                                                      color: Color(
                                                                          0xFF10B981),
                                                                    ),
                                                                    const SizedBox(
                                                                        width: 4),
                                                                    Text(
                                                                      brandName,
                                                                      style:
                                                                          const TextStyle(
                                                                        fontSize: 12,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .w600,
                                                                        color: Color(
                                                                            0xFF10B981),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                      ),
                                                      if (item['products'] != null) ...[
                                                        const SizedBox(width: 8),
                                                        InkWell(
                                                          onTap: () {
                                                            try {
                                                              final product = ProductModel.fromJson(Map<String, dynamic>.from(item['products']));
                                                              Navigator.push(
                                                                context,
                                                                MaterialPageRoute(
                                                                  builder: (context) => ProductDetailsScreen(product: product),
                                                                ),
                                                              );
                                                            } catch (e) {
                                                              print('Error opening product details from requested item: $e');
                                                            }
                                                          },
                                                          borderRadius: BorderRadius.circular(20),
                                                          child: Container(
                                                            padding: const EdgeInsets.all(6),
                                                            decoration: BoxDecoration(
                                                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                                              shape: BoxShape.circle,
                                                            ),
                                                            child: const Icon(
                                                              Icons.launch_rounded,
                                                              size: 14,
                                                              color: Color(0xFF8B5CF6),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Item Details
                                          Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Row(
                                              children: [
                                                // Size/Specification
                                                Expanded(
                                                  child: _buildInfoCard(
                                                    'Size/Spec',
                                                    qualityName,
                                                    Icons.straighten_rounded,
                                                    const Color(0xFF3B82F6),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                // Quantity
                                                Expanded(
                                                  child: _buildInfoCard(
                                                    'Quantity',
                                                    '${item['quantity'] ?? 0}',
                                                    Icons.shopping_cart_rounded,
                                                    const Color(0xFFF59E0B),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                // Unit
                                                Expanded(
                                                  child: _buildInfoCard(
                                                    'Unit',
                                                    item['unit'] ?? 'units',
                                                    Icons.scale_rounded,
                                                    const Color(0xFF8B5CF6),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Notes if available
                                          if (item['notes'] != null &&
                                              item['notes']
                                                  .toString()
                                                  .isNotEmpty) ...[
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(12),
                                              margin: const EdgeInsets.fromLTRB(
                                                  16, 0, 16, 16),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF9C3),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Icon(
                                                    Icons.note_alt_rounded,
                                                    size: 16,
                                                    color: Color(0xFFCA8A04),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      item['notes'].toString(),
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        color:
                                                            Color(0xFF854D0E),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Notes
                          if (widget.quote['notes'] != null &&
                              widget.quote['notes'].isNotEmpty) ...[
                            _buildSection(
                              'Notes',
                              Icons.note_outlined,
                              [
                                Text(
                                  widget.quote['notes'],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],
                        ],

                        const SizedBox(height: 24),
                      ],

                      // Action Buttons
                      if (!isOldSystem) ...[
                        const SizedBox(height: 24),
                        _buildActionButtons(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: const Color(0xFF8B5CF6),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  // Helper method for price columns in item cards
  Widget _buildPriceColumn(String label, String value, IconData icon) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Icon(
              icon,
              size: 16,
              color: const Color(0xFF64748B),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method for modern price rows in dark summary card
  Widget _buildModernPriceRow(String label, String value,
      {bool isSubtle = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSubtle ? Colors.white60 : Colors.white,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSubtle ? Colors.white70 : Colors.white,
          ),
        ),
      ],
    );
  }

  // Helper method for info cards with icons
  Widget _buildInfoCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 18,
            color: color,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _StickyFilterDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _StickyFilterDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight > minHeight ? maxHeight : minHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_StickyFilterDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}

// ═══════════════════════════════════════════════════════════
// Address Selection Sheet for Quotes
// ═══════════════════════════════════════════════════════════

class _AddressSelectionSheetWidget extends StatefulWidget {
  const _AddressSelectionSheetWidget();

  @override
  State<_AddressSelectionSheetWidget> createState() => _AddressSelectionSheetWidgetState();
}

class _AddressSelectionSheetWidgetState extends State<_AddressSelectionSheetWidget> {
  final _addressService = AddressService();
  List<AddressModel> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    try {
      final addresses = await _addressService.getAddresses();
      if (mounted) {
        setState(() {
          _addresses = addresses;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 50),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('Select Delivery Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF1E293B)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: const Color(0xFFF1F5F9)),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                itemCount: _addresses.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index == _addresses.length) {
                    return OutlinedButton.icon(
                      onPressed: () async {
                        final result = await showModalBottomSheet<bool>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const AddressFormSheet(),
                        );
                        if (result == true) _loadAddresses();
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add New Address'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4F46E5),
                        side: const BorderSide(color: Color(0xFF4F46E5)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    );
                  }

                  final address = _addresses[index];
                  return GestureDetector(
                    onTap: () => Navigator.pop(context, address.fullAddress),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(address.label, style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w700, fontSize: 11)),
                                    ),
                                    if (address.isDefault) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text('Default', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w700, fontSize: 11)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(address.fullAddress, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)), maxLines: 2, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

