import 'package:flutter/foundation.dart';
import 'package:contracto_app/features/products/data/models/product_model.dart';
import 'package:contracto_app/core/network/supabase_service.dart';
import 'package:contracto_app/features/credit/data/services/business_credit_service.dart';
import 'package:contracto_app/core/config/payment_config.dart';
import 'package:contracto_app/features/payment/data/services/razorpay_service.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal() {
    _loadCart(); // Load cart on initialization
  }

  final List<CartItem> _cartItems = [];
  final List<QuoteItem> _quoteItems = [];
  final RazorpayService _razorpayService = RazorpayService();

  List<CartItem> get cartItems => List.unmodifiable(_cartItems);
  List<QuoteItem> get quoteItems => List.unmodifiable(_quoteItems);

  int get cartItemCount => _cartItems.length;
  int get quoteItemCount => _quoteItems.length;

  double get cartTotal {
    return _cartItems.fold(0.0, (total, item) {
      return total + item.totalPrice;
    });
  }

  double get deliveryCharge {
    if (!PaymentConfig.deliveryChargeEnabled) return 0.0;
    if (subtotal > PaymentConfig.freeDeliveryThreshold) return 0.0;
    return PaymentConfig.baseDeliveryCharge;
  }

  double get subtotal => cartTotal;

  double get gstAmount {
    // Calculate GST based on individual items
    return _cartItems.fold(0.0, (total, item) {
      final gstPercent = item.product.gstPercent ?? (PaymentConfig.gstPercentage * 100);
      // Assuming item.totalPrice is the taxable value (base price * qty)
      final itemGst = (item.totalPrice * gstPercent) / 100;
      return total + itemGst;
    });
  }

  double get grandTotal => subtotal + deliveryCharge + gstAmount;

  double getItemGstAmount(CartItem item) {
    final gstPercent = item.product.gstPercent ?? (PaymentConfig.gstPercentage * 100);
    return (item.totalPrice * gstPercent) / 100;
  }

  void addToCart(ProductModel product, double quantity,
      {QualityOption? qualityOption, String? unit}) {
    final existingIndex = _cartItems.indexWhere(
      (item) =>
          item.product.id == product.id &&
          item.selectedQualityOption?.id == qualityOption?.id &&
          item.unit == unit, // Check if unit matches
    );

    if (existingIndex >= 0) {
      _cartItems[existingIndex].quantity += quantity;
    } else {
      _cartItems.add(CartItem(
        product: product,
        selectedQualityOption: qualityOption,
        quantity: quantity,
        unit: unit,
        addedAt: DateTime.now(),
      ));
    }
    notifyListeners();
    _saveCart(); // Save cart after adding item
  }

  void updateQuantity(String productId, double quantity) {
    final index = _cartItems.indexWhere(
      (item) => item.product.id == productId,
    );

    if (index >= 0) {
      if (quantity <= 0) {
        _cartItems.removeAt(index);
      } else {
        _cartItems[index].quantity = quantity;
      }
      notifyListeners();
      _saveCart(); // Save cart after updating quantity
    }
  }

  void removeFromCart(String productId) {
    _cartItems.removeWhere((item) => item.product.id == productId);
    notifyListeners();
    _saveCart(); // Save cart after removing item
  }

  void clearCart() {
    _cartItems.clear();
    notifyListeners();
    _saveCart(); // Save cart after clearing
  }

  // Clear all items (for payment integration)
  void clear() {
    _cartItems.clear();
    _quoteItems.clear();
    notifyListeners();
    _saveCart(); // Save cart after clearing
  }

  // Save cart to local storage
  Future<void> _saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartData = _cartItems.map((item) => item.toJson()).toList();
      final jsonString = jsonEncode(cartData);
      await prefs.setString('cart_items', jsonString);
      print('✅ Cart saved: ${_cartItems.length} items');
    } catch (e) {
      print('❌ Error saving cart: $e');
    }
  }

  // Load cart from local storage
  Future<void> _loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartString = prefs.getString('cart_items');
      
      print('📦 Loading cart from storage...');
      
      if (cartString != null && cartString.isNotEmpty) {
        print('📦 Found cart data: ${cartString.length} characters');
        final List<dynamic> cartData = jsonDecode(cartString);
        print('📦 Decoded ${cartData.length} items');
        
        _cartItems.clear();
        
        for (var item in cartData) {
          try {
            final cartItem = CartItem.fromJson(item);
            _cartItems.add(cartItem);
            print('✅ Loaded: ${cartItem.product.productName} x${cartItem.quantity}');
          } catch (e) {
            print('❌ Error loading cart item: $e');
            // Skip invalid items
          }
        }
        
        print('✅ Cart loaded successfully: ${_cartItems.length} items');
        notifyListeners();
      } else {
        print('📦 No cart data found in storage');
      }
    } catch (e) {
      print('❌ Error loading cart: $e');
    }
  }

  void addToQuote(ProductModel product, double quantity,
      {QualityOption? qualityOption, String? unit}) {
    final existingIndex = _quoteItems.indexWhere(
      (item) =>
          item.product.id == product.id &&
          item.selectedQualityOption?.id == qualityOption?.id,
    );

    if (existingIndex >= 0) {
      _quoteItems[existingIndex].quantity += quantity;
    } else {
      _quoteItems.add(QuoteItem(
        product: product,
        selectedQualityOption: qualityOption,
        quantity: quantity,
        unit: unit,
        addedAt: DateTime.now(),
      ));
    }
    notifyListeners();
  }

  void updateQuoteQuantity(String productId, double quantity) {
    final index = _quoteItems.indexWhere(
      (item) => item.product.id == productId,
    );

    if (index >= 0) {
      if (quantity <= 0) {
        _quoteItems.removeAt(index);
      } else {
        _quoteItems[index].quantity = quantity;
      }
      notifyListeners();
    }
  }

  void removeFromQuote(String productId) {
    _quoteItems.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void clearQuotes() {
    _quoteItems.clear();
    notifyListeners();
  }

  Future<bool> submitQuoteRequest({
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    String? deliveryAddress,
    String? notes,
  }) async {
    try {
      final currentUser = SupabaseService.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get user ID from users table
      final userData = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('email', currentUser.email!)
          .maybeSingle();

      if (userData == null) {
        throw Exception('User not found in database');
      }

      final quoteData = {
        'user_id': userData['id'],
        'customer_name': customerName,
        'customer_email': customerEmail,
        'customer_phone': customerPhone,
        'delivery_address': deliveryAddress,
        'notes': notes,
        'status': 'pending',
        'total_amount': cartTotal,
        'items': _quoteItems
            .map((item) => {
                  'product_id': item.product.id,
                  'product_name': item.displayName,
                  'quantity': item.quantity,
                  'unit_price': item.totalPrice / item.quantity,
                  'total_price': item.totalPrice,
                  'quality_option': item.selectedQualityOption?.toJson(),
                  'unit': item.unit ?? item.product.unit,
                  'image_url': item.product.photos.isNotEmpty ? item.product.photos.first : null,
                  'product_image': item.product.photos.isNotEmpty ? item.product.photos.first : null,
                })
            .toList(),
        'created_at': DateTime.now().toIso8601String(),
      };

      await SupabaseService.client.from('quotations').insert([quoteData]);

      // Clear quotes after successful submission
      clearQuotes();
      return true;
    } catch (e) {
      print('Error submitting quote request: $e');
      return false;
    }
  }

  Future<OrderResult> submitOrder({
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required String deliveryAddress,
    required String paymentMethod,
    String? deliveryType,
    String? notes,
    String? gstNumber,
    double discount = 0,
  }) async {
    try {
      final currentUser = SupabaseService.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get user ID from users table
      final userData = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('email', currentUser.email!)
          .maybeSingle();

      if (userData == null) {
        throw Exception('User not found in database');
      }

      final totalAmount = grandTotal - discount;
      final gstValue = gstAmount;

      // Business Credit Validation & Deduction
      if (paymentMethod == 'Business Credit') {
        final creditService = BusinessCreditService();
        
        // Check eligibility
        final isEligible = await creditService.isEligibleForCredit();
        if (!isEligible) {
          return OrderResult(
            success: false,
            message: 'Business credit is not available. Please complete KYC verification.',
          );
        }

        // Get available credit
        final availableCredit = await creditService.getAvailableCredit();
        if (availableCredit < totalAmount) {
          return OrderResult(
            success: false,
            message: 'Insufficient business credit available. Available: ₹${availableCredit.toStringAsFixed(2)}',
          );
        }

        // Check if account is frozen
        final isFrozen = await creditService.isAccountFrozen();
        if (isFrozen) {
          return OrderResult(
            success: false,
            message: 'Your account is frozen due to overdue payment. Please clear your dues.',
          );
        }

        // Note: Credit will be deducted after order is created
        // We'll do it after order creation to ensure order ID is available
      }

      final orderData = {
        'user_id': userData['id'],
        'customer_name': customerName,
        'customer_email': customerEmail,
        'customer_phone': customerPhone,
        'delivery_address': deliveryAddress,
        'delivery_type': deliveryType ?? 'home_delivery',
        'payment_method': paymentMethod,
        'notes': notes,
        'gst_number': gstNumber,
        'order_status': 'pending',
        // Credit payments are 'pending' until settled, COD is 'pending', Online is 'paid'
        'payment_status': paymentMethod == 'Business Credit' ? 'pending' : 'pending',
        'payment_source': paymentMethod == 'Business Credit'
            ? 'credit'
            : (paymentMethod == 'Direct Bank Transfer'
                ? 'bank_transfer'
                : (paymentMethod == 'Cash on Delivery' ? 'cash_on_delivery' : 'direct')),
        'total_amount': totalAmount,
        'subtotal': subtotal,
        'gst_amount': gstValue,
        'delivery_charge': deliveryCharge,
        'invoice_required': gstNumber != null,
        'items': _cartItems
            .map((item) => {
                  'product_id': item.product.id,
                  'product_name': item.displayName,
                  'quantity': item.quantity,
                  'unit_price': item.totalPrice / item.quantity,
                  'total_price': item.totalPrice,
                  'quality_option': item.selectedQualityOption?.toJson(),
                  'unit': item.unit ?? item.product.unit, // Save unit to order items
                  'is_returnable': item.product.isReturnable,
                  'image_url': item.product.photos.isNotEmpty ? item.product.photos.first : null, // Save image URL for displaying
                  'product_image': item.product.photos.isNotEmpty ? item.product.photos.first : null,
                })
            .toList(),
        'created_at': DateTime.now().toIso8601String(),
      };

      // Debug print
      print('Submitting Order: $orderData');

      final order = await SupabaseService.client
          .from('orders')
          .insert([orderData])
          .select()
          .single();

      // Deduct credit after order creation (if Business Credit payment)
      if (paymentMethod == 'Business Credit') {
        try {
          final creditService = BusinessCreditService();
          await creditService.useCredit(
            orderId: order['id'],
            amount: totalAmount,
            description: 'Order payment - Order #${order['id'].toString().substring(0, 8)}',
          );
          print('✅ Credit deducted successfully for order ${order['id']}');
        } catch (e) {
          print('❌ CRITICAL: Credit deduction failed for order ${order['id']}: $e');
          // Cancel the order since credit was not deducted
          try {
            await SupabaseService.client.from('orders').update({
              'order_status': 'cancelled',
              'status_notes': 'Auto-cancelled: Credit deduction failed - $e',
            }).eq('id', order['id']);
          } catch (_) {}
          
          clearCart();
          return OrderResult(
            success: false,
            message: 'Credit deduction failed: $e. Order has been cancelled.',
          );
        }
      }

      // Clear cart after successful submission
      clearCart();

      return OrderResult(
        success: true,
        message: 'Order placed successfully!',
        orderId: order['id'],
        transactionId: null,
      );
    } catch (e) {
      print('Error submitting order: $e');
      return OrderResult(
        success: false,
        message: 'Failed to place order: $e',
      );
    }
  }


  // Handle online payment with Razorpay
  Future<PaymentResult> processOnlinePayment({
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required String deliveryAddress,
    required String notes,
    String? gstNumber,
    double discount = 0,
    required Function(PaymentSuccessResponse) onPaymentSuccess,
    required Function(PaymentFailureResponse) onPaymentFailure,
    required Function(ExternalWalletResponse) onExternalWallet,
  }) async {
    try {
      // Initialize Razorpay with callbacks
      _razorpayService.initialize(
        onPaymentSuccess: onPaymentSuccess,
        onPaymentFailure: onPaymentFailure,
        onExternalWallet: onExternalWallet,
      );

      // Calculate final amount after applying discount
      final finalAmount = (grandTotal - discount).clamp(0.0, double.infinity);
      
      // Generate a unique receipt ID
      final receiptId = 'ORDER_${DateTime.now().millisecondsSinceEpoch}';

      // Create Razorpay order
      final orderResult = await _razorpayService.createPaymentOrder(
        amount: finalAmount,
        currency: PaymentConfig.defaultCurrency,
        receipt: receiptId,
        customerName: customerName,
        customerEmail: customerEmail,
        customerPhone: customerPhone,
      );

      if (!orderResult['success']) {
        return PaymentResult(
          success: false,
          message: orderResult['error'] ?? 'Failed to create payment order. Please try again.',
        );
      }

      final razorpayOrderId = orderResult['order_id'] as String;

      // Start Razorpay payment
      _razorpayService.startPayment(
        orderId: razorpayOrderId,
        keyId: PaymentConfig.razorpayKey,
        amount: finalAmount,
        currency: PaymentConfig.defaultCurrency,
        customerName: customerName,
        customerEmail: customerEmail,
        customerPhone: customerPhone,
        description: 'Order Payment - Contracto',
      );

      // Return success - the actual payment result will be handled by callbacks
      return PaymentResult(
        success: true,
        message: 'Payment gateway opened',
        orderId: razorpayOrderId,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error processing online payment: $e');
      }
      return PaymentResult(
        success: false,
        message: 'Error processing payment: ${e.toString()}',
      );
    }
  }

  // Create order after successful payment
  Future<OrderResult> createOrderAfterPayment({
    required String paymentId,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required String deliveryAddress,
    String? deliveryType,
    required String notes,
    String? gstNumber,
    double discount = 0,
  }) async {
    try {
      final currentUser = SupabaseService.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get user ID from users table
      final userData = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('email', currentUser.email!)
          .maybeSingle();

      if (userData == null) {
        throw Exception('User not found in database');
      }

      final orderData = {
        'user_id': userData['id'],
        'customer_name': customerName,
        'customer_email': customerEmail,
        'customer_phone': customerPhone,
        'delivery_address': deliveryAddress,
        'delivery_type': deliveryType ?? 'home_delivery',
        'payment_method': 'Online Payment',
        'payment_status': 'paid',
        'payment_source': 'online',
        'transaction_id': paymentId,
        'order_status': 'confirmed',
        'notes': notes.isNotEmpty ? '$notes | Payment ID: $paymentId' : 'Payment ID: $paymentId',
        'gst_number': gstNumber,
        'total_amount': grandTotal - discount,
        'subtotal': cartTotal,
        'gst_amount': gstNumber != null ? gstAmount : 0,
        'delivery_charge': deliveryCharge,
        'invoice_required': gstNumber != null,
        'items': _cartItems
            .map((item) => {
                  'product_id': item.product.id,
                  'product_name': item.displayName,
                  'quantity': item.quantity,
                  'unit_price': item.totalPrice / item.quantity,
                  'total_price': item.totalPrice,
                  'quality_option': item.selectedQualityOption?.toJson(),
                  'unit': item.unit ?? item.product.unit,
                  'is_returnable': item.product.isReturnable,
                  'product_image': item.product.photos.isNotEmpty ? item.product.photos.first : null,
                })
            .toList(),
        'created_at': DateTime.now().toIso8601String(),
      };

      final order = await SupabaseService.client
          .from('orders')
          .insert([orderData])
          .select()
          .single();

      // Clear cart after successful order creation
      clearCart();

      return OrderResult(
        success: true,
        message: 'Order placed successfully!',
        orderId: order['id'],
        transactionId: paymentId,
      );
    } catch (e) {
      print('Error creating order after payment: $e');
      return OrderResult(
        success: false,
        message: 'Failed to create order: $e',
      );
    }
  }
}

class CartItem {
  final ProductModel product;
  final QualityOption? selectedQualityOption;
  double quantity;
  final String? unit; // Added unit field
  final DateTime addedAt;

  CartItem({
    required this.product,
    this.selectedQualityOption,
    required this.quantity,
    this.unit,
    required this.addedAt,
  });

  // Getter for price (for payment integration)
  double get price {
    if (selectedQualityOption != null) {
      return selectedQualityOption!.finalPrice ??
          selectedQualityOption!.mrp ??
          0;
    }
    return product.finalPrice ?? product.mrp ?? 0;
  }

  // Getter for quality option ID (for payment integration)
  String? get qualityOptionId {
    return selectedQualityOption?.id;
  }

  // Getter for quality option name (for payment integration)
  String get qualityOptionName {
    return selectedQualityOption?.name ?? 'Standard';
  }

  double get totalPrice {
    return price * quantity;
  }

  String get displayName {
    if (selectedQualityOption != null) {
      return '${product.productName} (${selectedQualityOption!.name})';
    }
    return product.productName;
  }

  // Serialization methods for cart persistence
  Map<String, dynamic> toJson() {
    return {
      'product': product.toJson(),
      'selectedQualityOption': selectedQualityOption?.toJson(),
      'quantity': quantity,
      'unit': unit,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      product: ProductModel.fromJson(json['product']),
      selectedQualityOption: json['selectedQualityOption'] != null
          ? QualityOption.fromJson(json['selectedQualityOption'])
          : null,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'],
      addedAt: DateTime.parse(json['addedAt']),
    );
  }
}

class QuoteItem {
  final ProductModel product;
  final QualityOption? selectedQualityOption;
  double quantity;
  final String? unit;
  final DateTime addedAt;

  QuoteItem({
    required this.product,
    this.selectedQualityOption,
    required this.quantity,
    this.unit,
    required this.addedAt,
  });

  double get totalPrice {
    if (selectedQualityOption != null) {
      final price =
          selectedQualityOption!.finalPrice ?? selectedQualityOption!.mrp ?? 0;
      return price * quantity;
    }
    final price = product.finalPrice ?? product.mrp ?? 0;
    return price * quantity;
  }

  String get displayName {
    if (selectedQualityOption != null) {
      return '${product.productName} (${selectedQualityOption!.name})';
    }
    return product.productName;
  }
}

class OrderResult {
  final bool success;
  final String message;
  final String? orderId;
  final String? transactionId;

  OrderResult({
    required this.success,
    required this.message,
    this.orderId,
    this.transactionId,
  });
}
