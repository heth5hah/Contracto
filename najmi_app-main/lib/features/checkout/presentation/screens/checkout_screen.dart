import 'package:flutter/material.dart';
import 'package:contracto_app/features/cart/data/services/cart_service.dart';
import 'package:contracto_app/features/auth/data/models/user_model.dart';
import 'package:contracto_app/features/auth/data/services/user_service.dart';
import 'package:contracto_app/core/network/supabase_service.dart';
import 'package:contracto_app/features/payment/presentation/screens/payment_success_screen.dart';
import 'package:contracto_app/features/payment/presentation/screens/payment_failure_screen.dart';
import 'package:contracto_app/features/checkout/data/services/coupon_service.dart';
import 'package:contracto_app/features/checkout/data/models/coupon_model.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:contracto_app/features/credit/data/services/business_credit_service.dart';
import 'package:contracto_app/features/address/data/models/address_model.dart';
import 'package:contracto_app/features/address/data/services/address_service.dart';
import 'package:contracto_app/features/address/presentation/screens/address_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userService = UserService();
  final _cartService = CartService();

  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _gstController = TextEditingController();
  final _couponController = TextEditingController();

  final _couponService = CouponService();
  final _creditService = BusinessCreditService();
  final _addressService = AddressService();
  CouponModel? _appliedCoupon;
  double _couponDiscount = 0;
  bool _isValidatingCoupon = false;
  List<CouponModel> _availableCoupons = [];
  bool _isLoadingCoupons = true;

  // Address management
  List<AddressModel> _addresses = [];
  AddressModel? _selectedAddress;
  bool _isLoadingAddresses = true;

  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isLoadingUser = true;
  bool _wantGstInvoice = false;
  String _selectedPaymentMethod = 'online';
  String _deliveryType = 'home_delivery';
  bool _isBusinessAccount = false;
  bool _isCreditEligible = false;
  double _availableCredit = 0.0;
  bool _isAccountFrozen = false;

  // Theme constants
  static const _indigo = Color(0xFF4F46E5);
  static const _indigoLight = Color(0xFF6366F1);
  static const _dark = Color(0xFF1E293B);
  static const _slate500 = Color(0xFF64748B);
  static const _slate200 = Color(0xFFE2E8F0);
  static const _bg = Color(0xFFF8FAFC);

  // Shop pickup address
  static const _shopAddress =
      'Najmi Electricals and Hardware, Dr Ambedkar Road, Shivaji Chowk, '
      'Kalyan West, near pathare nursery, Kalyan, Maharashtra 421301';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadAddresses();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _gstController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final currentUser = SupabaseService.instance.currentUser;
      if (currentUser != null) {
        final userData = await _userService.getUserByEmail(currentUser.email!);
        if (userData != null && mounted) {
          final isBusiness = userData.isCompany;
          bool isCreditEligible = false;
          double availableCredit = 0.0;

          final creditAccount = await _creditService.getCreditAccount();
          if (creditAccount != null) {
            isCreditEligible = true;
            availableCredit = (creditAccount['available_credit'] as num).toDouble();
          } else if (isBusiness) {
            isCreditEligible = await _creditService.isEligibleForCredit();
            if (isCreditEligible) {
              availableCredit = await _creditService.getAvailableCredit();
            }
          }
          
          if (isCreditEligible) {
            _isAccountFrozen = await _creditService.isAccountFrozen();
          }

          setState(() {
            _currentUser = userData;
            _isBusinessAccount = isBusiness;
            _isCreditEligible = isCreditEligible;
            _availableCredit = availableCredit;
            _nameController.text = userData.name;
            _emailController.text = userData.email ?? '';
            _phoneController.text = userData.mobile;

            if (userData.isCompany || userData.isGstRegistered) {
              _gstController.text = userData.gstNumber ?? '';
              _wantGstInvoice = userData.gstNumber?.isNotEmpty ?? false;
            }
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      await _loadAvailableCoupons();
      if (mounted) {
        setState(() => _isLoadingUser = false);
      }
    }
  }

  Future<void> _loadAvailableCoupons() async {
    try {
      final coupons = await _couponService.getActiveCoupons(
        userEmail: _currentUser?.email,
        cartItems: _cartService.cartItems,
      );
      if (mounted) {
        setState(() {
          _availableCoupons = coupons;
          _isLoadingCoupons = false;
        });
      }
    } catch (e) {
      print('Error loading available coupons: $e');
      if (mounted) {
        setState(() => _isLoadingCoupons = false);
      }
    }
  }

  Future<void> _validateCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isValidatingCoupon = true);

    try {
      final subtotal = _cartService.cartTotal;
      final coupon = await _couponService.validateCoupon(
        code, subtotal,
        userEmail: _currentUser?.email,
        cartItems: _cartService.cartItems,
      );
      if (coupon == null) throw Exception('Invalid coupon');
      final discount = coupon.calculateDiscount(subtotal, cartItems: _cartService.cartItems);

      if (mounted) {
        setState(() {
          _appliedCoupon = coupon;
          _couponDiscount = discount;
          _isValidatingCoupon = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Coupon applied! You saved ₹${discount.toStringAsFixed(2)}'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isValidatingCoupon = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _loadAddresses() async {
    try {
      final addresses = await _addressService.getAddresses();
      final defaultAddress = await _addressService.getDefaultAddress();
      if (mounted) {
        setState(() {
          _addresses = addresses;
          _selectedAddress = defaultAddress ?? (addresses.isNotEmpty ? addresses.first : null);
          if (_selectedAddress != null) {
            _addressController.text = _selectedAddress!.fullAddress;
          }
          _isLoadingAddresses = false;
        });
      }
    } catch (e) {
      print('Error loading addresses: $e');
      if (mounted) setState(() => _isLoadingAddresses = false);
    }
  }

  void _showAddressSelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAddressSelectionSheet(),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        fontSize: 14,
        color: _slate500,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(icon, color: _indigo, size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _slate200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _slate200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _indigo, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: _buildAppBar(),
        body: const Center(
          child: CircularProgressIndicator(color: _indigo),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Freeze warning banner
                    if (_isAccountFrozen) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.ac_unit, color: Color(0xFFEF4444), size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Account Frozen',
                                    style: TextStyle(color: Color(0xFFB91C1C), fontSize: 14, fontWeight: FontWeight.w700),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Your business credit is frozen due to overdue payment. Clear your dues to re-enable credit.',
                                    style: TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    _buildSectionCard(
                      icon: Icons.person_rounded,
                      title: 'Customer Information',
                      badge: (_currentUser?.isCompany ?? false) ? 'Business' : null,
                      child: _buildCustomerFields(),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      icon: Icons.local_shipping_rounded,
                      title: 'Delivery Type',
                      child: _buildDeliveryTypeToggle(),
                    ),
                    if (_deliveryType == 'home_delivery') ...[
                      const SizedBox(height: 16),
                      _buildSectionCard(
                        icon: Icons.location_on_rounded,
                        title: 'Delivery Address',
                        trailing: _addresses.isNotEmpty
                            ? GestureDetector(
                                onTap: _showAddressSelectionSheet,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _indigo.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Change',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _indigo,
                                    ),
                                  ),
                                ),
                              )
                            : null,
                        child: _buildAddressContent(),
                      ),
                    ],
                    if (_deliveryType == 'pickup_from_shop') ...[
                      const SizedBox(height: 16),
                      _buildSectionCard(
                        icon: Icons.storefront_rounded,
                        title: 'Pickup Address',
                        child: _buildPickupAddressCard(),
                      ),
                    ],
                    if (_currentUser?.isIndividual ?? true) ...[
                      const SizedBox(height: 16),
                      _buildSectionCard(
                        icon: Icons.receipt_long_rounded,
                        title: 'GST Invoice',
                        child: _buildGstContent(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      icon: Icons.payment_rounded,
                      title: 'Payment Method',
                      child: _buildPaymentContent(),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      icon: Icons.note_alt_rounded,
                      title: 'Order Notes',
                      subtitle: 'Optional',
                      child: TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: _inputDecoration('Any special instructions...', Icons.edit_note_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCouponSection(),
                    const SizedBox(height: 16),
                    _buildOrderSummary(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
          _buildBottomPaymentButton(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: _dark,
          ),
        ),
      ),
      title: const Text(
        'Checkout',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: _dark,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    String? subtitle,
    String? badge,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _indigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _indigo, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '($subtitle)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _slate500,
                        ),
                      ),
                    ],
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_indigo, _indigoLight],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildCustomerFields() {
    return Column(
      children: [
        TextFormField(
          controller: _nameController,
          decoration: _inputDecoration(
            _currentUser?.isCompany ?? false ? 'Contact Person' : 'Full Name',
            Icons.person_outline_rounded,
          ),
          validator: (value) => (value == null || value.trim().isEmpty) ? 'Name is required' : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: _inputDecoration('Email Address', Icons.mail_outline_rounded),
          validator: (value) => (value == null || value.trim().isEmpty) ? 'Email is required' : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: _inputDecoration('Phone Number', Icons.phone_outlined),
          validator: (value) => (value == null || value.trim().isEmpty) ? 'Phone number is required' : null,
        ),
        if (_currentUser?.isCompany ?? false) ...[
          const SizedBox(height: 14),
          TextFormField(
            initialValue: _currentUser?.companyName ?? '',
            readOnly: true,
            decoration: _inputDecoration('Company Name', Icons.business_outlined),
          ),
        ],
      ],
    );
  }

  Widget _buildDeliveryTypeToggle() {
    return Row(
      children: [
        _deliveryOption(
          icon: Icons.home_rounded,
          label: 'Home Delivery',
          value: 'home_delivery',
        ),
        const SizedBox(width: 12),
        _deliveryOption(
          icon: Icons.storefront_rounded,
          label: 'Pick up from Shop',
          value: 'pickup_from_shop',
        ),
      ],
    );
  }

  Widget _deliveryOption({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final isSelected = _deliveryType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _deliveryType = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? _indigo.withValues(alpha: 0.06) : Colors.white,
            border: Border.all(
              color: isSelected ? _indigo : _slate200,
              width: isSelected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? _indigo : _slate500, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? _indigo : _slate500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickupAddressCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Shop',
                  style: TextStyle(
                    color: Color(0xFF065F46),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Pickup Point',
                  style: TextStyle(
                    color: Color(0xFF065F46),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _shopAddress,
            style: const TextStyle(fontSize: 14, color: _slate500, height: 1.4),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF10B981)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Please collect your order from the shop at the above address.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddressContent() {
    if (_isLoadingAddresses) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(color: _indigo, strokeWidth: 2),
        ),
      );
    }
    if (_selectedAddress != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _indigo.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _indigo.withValues(alpha: 0.2), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _indigo.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _selectedAddress!.label,
                    style: const TextStyle(
                      color: _indigo,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                if (_selectedAddress!.isDefault) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Default',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _selectedAddress!.fullAddress,
              style: const TextStyle(fontSize: 14, color: _slate500, height: 1.4),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        const Text(
          'No saved addresses found',
          style: TextStyle(fontSize: 14, color: _slate500),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
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
            label: const Text('Add Delivery Address'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _indigo,
              side: const BorderSide(color: _indigo),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGstContent() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: CheckboxListTile(
            title: const Text('I want GST invoice', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(
              _currentUser?.isCompany ?? false
                  ? 'GST invoice generated automatically for business accounts'
                  : 'Check this if you need a GST invoice',
              style: const TextStyle(fontSize: 12, color: _slate500),
            ),
            value: (_currentUser?.isCompany ?? false) || _wantGstInvoice,
            onChanged: (_currentUser?.isCompany ?? false)
                ? null
                : (bool? value) {
                    setState(() {
                      _wantGstInvoice = value ?? false;
                      if (!_wantGstInvoice) _gstController.clear();
                    });
                  },
            activeColor: _indigo,
            checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        if ((_currentUser?.isCompany ?? false) || _wantGstInvoice) ...[
          const SizedBox(height: 14),
          TextFormField(
            controller: _gstController,
            textCapitalization: TextCapitalization.characters,
            decoration: _inputDecoration('GST Number', Icons.receipt_outlined),
            validator: (value) {
              if ((_currentUser?.isCompany ?? false) || _wantGstInvoice) {
                if (value == null || value.trim().isEmpty) return 'GST number is required';
                if (!_isValidGst(value)) return 'Please enter a valid GST number';
              }
              return null;
            },
            readOnly: _currentUser?.isCompany ?? false,
          ),
          if (_currentUser?.isIndividual ?? true) ...[
            const SizedBox(height: 6),
            Text(
              'Format: 22AAAAA0000A1Z5',
              style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildPaymentContent() {
    return Column(
      children: [
        _paymentOption(
          icon: Icons.credit_card_rounded,
          title: 'Online Payment',
          subtitle: 'UPI, Netbanking, or Wallet',
          value: 'online',
        ),
        if (_isBusinessAccount || (!_isBusinessAccount && _isCreditEligible)) ...[
          const SizedBox(height: 10),
          if (_isCreditEligible)
            _paymentOption(
              icon: Icons.account_balance_wallet_rounded,
              title: _isBusinessAccount ? 'Business Credit' : 'Wallet',
              subtitle: 'Available: ₹${_availableCredit.toStringAsFixed(0)}',
              value: 'credit',
              disabled: _cartService.grandTotal > _availableCredit || _isAccountFrozen,
              extraInfo: _isAccountFrozen 
                  ? 'Account is frozen. Clear dues to use credit.'
                  : (_cartService.grandTotal > _availableCredit
                      ? 'Insufficient credit for this order'
                      : (_selectedPaymentMethod == 'credit'
                          ? 'Remaining: ₹${(_availableCredit - _cartService.grandTotal).toStringAsFixed(0)}'
                          : null)),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.account_balance_wallet_outlined, color: Colors.grey[400], size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_isBusinessAccount ? 'Business Credit' : 'Wallet', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[500], fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(_isBusinessAccount ? 'Not activated — contact admin' : 'Wallet is empty', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 10),
        _paymentOption(
          icon: Icons.money_rounded,
          title: 'Cash on Delivery (COD)',
          subtitle: 'Pay in cash when your order arrives',
          value: 'cash_on_delivery',
        ),
        const SizedBox(height: 10),
        _paymentOption(
          icon: Icons.account_balance_rounded,
          title: 'Direct Bank Transfer',
          subtitle: 'Transfer to our bank and enter Ref ID',
          value: 'bank_transfer',
        ),
      ],
    );
  }

  Widget _paymentOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    bool disabled = false,
    String? extraInfo,
  }) {
    final isSelected = _selectedPaymentMethod == value;
    return GestureDetector(
      onTap: disabled ? null : () => setState(() => _selectedPaymentMethod = value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? _indigo.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _indigo : _slate200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? _indigo.withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: isSelected ? _indigo : _slate500, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: disabled ? Colors.grey[400] : _dark,
                    fontSize: 14,
                  )),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: disabled ? Colors.grey[400] : _slate500)),
                  if (extraInfo != null) ...[
                    const SizedBox(height: 4),
                    Text(extraInfo, style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: disabled ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    )),
                  ],
                ],
              ),
            ),
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? _indigo : _slate200,
                  width: isSelected ? 6 : 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCouponSection() {
    return _buildSectionCard(
      icon: Icons.local_offer_rounded,
      title: 'Coupon Code',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _couponController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _inputDecoration('Enter coupon code', Icons.confirmation_number_outlined),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _isValidatingCoupon ? null : _validateCoupon,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_indigo, _indigoLight]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _isValidatingCoupon
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : const Text('Apply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ],
          ),
          if (_appliedCoupon != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_appliedCoupon!.code} applied — Saved ₹${_couponDiscount.toStringAsFixed(0)}',
                      style: const TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _appliedCoupon = null;
                        _couponDiscount = 0;
                        _couponController.clear();
                      });
                    },
                    child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF065F46)),
                  ),
                ],
              ),
            ),
          ],
          if (_availableCoupons.isNotEmpty && _appliedCoupon == null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _indigo.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _indigo.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Available Coupons — Tap to Apply',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _dark),
                  ),
                  const SizedBox(height: 10),
                  if (_isLoadingCoupons)
                    const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _indigo))
                  else
                    ...List.generate(_availableCoupons.length, (index) {
                      final coupon = _availableCoupons[index];
                      final desc = _getCouponDescription(coupon);
                      return Padding(
                        padding: EdgeInsets.only(bottom: index < _availableCoupons.length - 1 ? 8 : 0),
                        child: _buildCouponChip(coupon.code, desc),
                      );
                    }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCouponChip(String code, String description) {
    return GestureDetector(
      onTap: () {
        setState(() => _couponController.text = code);
        _validateCoupon();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _indigo.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _indigo.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                code,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _indigo, letterSpacing: 0.5),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(description, style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _indigo),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    final cartTotal = _cartService.cartTotal;
    final deliveryCharge = _cartService.deliveryCharge;
    final gstAmount = _cartService.gstAmount;
    final grandTotal = _cartService.grandTotal;
    final finalTotal = grandTotal - _couponDiscount;

    bool hasNonReturnable = _cartService.cartItems.any((item) => !item.product.isReturnable);

    return Column(
      children: [
        if (hasNonReturnable) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Color(0xFFEF4444), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Non-returnable items in your order',
                        style: TextStyle(color: Color(0xFFB91C1C), fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._cartService.cartItems
                    .where((item) => !item.product.isReturnable)
                    .map((item) => Padding(
                          padding: const EdgeInsets.only(left: 26, bottom: 3),
                          child: Text('• ${item.product.productName}',
                              style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12)),
                        )),
              ],
            ),
          ),
        ],
        _buildSectionCard(
          icon: Icons.receipt_rounded,
          title: 'Order Summary',
          child: Column(
            children: [
              _summaryRow('Items Total (${_cartService.cartItems.length})', '₹${cartTotal.round()}'),
              const SizedBox(height: 10),
              _summaryRow('Delivery', deliveryCharge == 0 ? 'Free' : '₹${deliveryCharge.round()}',
                  valueColor: deliveryCharge == 0 ? const Color(0xFF10B981) : null),
              if (gstAmount > 0) ...[
                const SizedBox(height: 10),
                _summaryRow('GST (Total)', '₹${gstAmount.round()}'),
              ],
              if (_couponDiscount > 0) ...[
                const SizedBox(height: 10),
                _summaryRow('Coupon Discount', '- ₹${_couponDiscount.toStringAsFixed(0)}',
                    valueColor: const Color(0xFF10B981)),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Container(height: 1, color: const Color(0xFFF1F5F9)),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Amount', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _dark)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _indigo.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '₹${finalTotal.round()}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _indigo),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: _slate500, fontWeight: FontWeight.w500)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor ?? _dark)),
      ],
    );
  }

  Widget _buildBottomPaymentButton() {
    final grandTotal = _cartService.grandTotal - _couponDiscount;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: GestureDetector(
          onTap: (_isLoading || _isAccountFrozen) ? null : _placeOrder,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: (_isLoading || _isAccountFrozen)
                  ? null
                  : const LinearGradient(colors: [_indigo, _indigoLight]),
              color: (_isLoading || _isAccountFrozen) ? Colors.grey[400] : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: (_isLoading || _isAccountFrozen)
                  ? null
                  : [
                      BoxShadow(
                        color: _indigo.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: _isLoading
                ? const Center(
                    child: SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _selectedPaymentMethod == 'online'
                            ? Icons.payment_rounded
                            : _selectedPaymentMethod == 'cash_on_delivery'
                                ? Icons.money_rounded
                                : Icons.account_balance_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${_selectedPaymentMethod == 'online' ? 'Pay Now' : 'Place Order'}  •  ₹${grandTotal.round()}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.2),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ── Business Logic (unchanged) ──

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;

    if (_currentUser?.status == 'blocked') {
      _showSnackBar('Your account has been blocked. You cannot place orders.', isError: true);
      return;
    }

    if (_deliveryType == 'home_delivery' && (_selectedAddress == null || _addressController.text.trim().isEmpty)) {
      _showSnackBar('Please select a delivery address before placing the order', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_selectedPaymentMethod == 'online') {
        await _processOnlinePayment();
        return;
      }

      final finalAmount = _cartService.grandTotal - _couponDiscount;
      final totalItems = _cartService.cartItems.length;

      // Map internal payment method value to display/DB string
      String paymentMethodLabel;
      if (_selectedPaymentMethod == 'credit') {
        paymentMethodLabel = 'Business Credit';
      } else if (_selectedPaymentMethod == 'cash_on_delivery') {
        paymentMethodLabel = 'Cash on Delivery';
      } else {
        paymentMethodLabel = 'Direct Bank Transfer';
      }

      final orderResult = await _cartService.submitOrder(
        customerName: _nameController.text.trim(),
        customerEmail: _emailController.text.trim(),
        customerPhone: _phoneController.text.trim(),
        deliveryAddress: _deliveryType == 'pickup_from_shop' ? _shopAddress : _addressController.text.trim(),
        deliveryType: _deliveryType,
        paymentMethod: paymentMethodLabel,
        notes: _notesController.text.trim(),
        gstNumber: ((_currentUser?.isCompany ?? false) || _wantGstInvoice) ? _gstController.text.trim() : null,
        discount: _couponDiscount,
      );

      if (orderResult.success && mounted) {
        // COD orders don't need a transaction ID — go straight to success
        if (_selectedPaymentMethod == 'cash_on_delivery') {
          if (mounted) setState(() => _isLoading = false);
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => PaymentSuccessScreen(
                  orderId: orderResult.orderId ?? '',
                  amount: finalAmount,
                  itemCount: totalItems,
                ),
              ),
            );
          }
          return;
        }

        // For credit — collect Transaction ID. Skip for bank transfer.
        if (_selectedPaymentMethod == 'credit') {
          if (mounted) setState(() => _isLoading = false);
          final txnId = await _showTransactionIdDialog(
            orderId: orderResult.orderId ?? '',
            isCreditPayment: true,
          );

          // Save transaction ID to the order
          if (txnId != null && txnId.isNotEmpty && orderResult.orderId != null) {
            try {
              await SupabaseService.client.from('orders').update({
                'transaction_id': txnId,
                'payment_status': 'awaiting_confirmation',
              }).eq('id', orderResult.orderId!);
              print('✅ Transaction ID saved: $txnId');
            } catch (e) {
              print('⚠️ Failed to save transaction ID: $e');
            }
          }
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentSuccessScreen(
                orderId: orderResult.orderId ?? '',
                amount: finalAmount,
                itemCount: totalItems,
              ),
            ),
          );
        }
      } else {
        _showSnackBar(orderResult.message, isError: true);
      }
    } catch (e) {
      _showSnackBar('Error placing order: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Shows a required dialog to collect Transaction ID after order placement
  Future<String?> _showTransactionIdDialog({
    required String orderId,
    bool isCreditPayment = false,
  }) async {
    final txnController = TextEditingController(
      text: isCreditPayment ? 'CREDIT-${DateTime.now().millisecondsSinceEpoch}' : '',
    );
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      barrierDismissible: false, // Can't dismiss without entering ID
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _indigo.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: _indigo, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Transaction ID', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Please enter your payment transaction ID for tracking.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: txnController,
                autofocus: !isCreditPayment,
                decoration: InputDecoration(
                  labelText: isCreditPayment ? 'Credit Reference ID' : 'UPI / Bank Reference ID',
                  hintText: isCreditPayment ? 'Auto-generated for credit' : 'e.g., UPI Ref Number / NEFT ID',
                  prefixIcon: const Icon(Icons.numbers, color: _indigo, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _indigo, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Transaction ID is required';
                  }
                  return null;
                },
              ),
              if (!isCreditPayment) ...[
                const SizedBox(height: 8),
                Text(
                  'You can find this in your bank app or UPI history.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(txnController.text.trim());
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Submit & Continue', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processOnlinePayment() async {
    if (_currentUser?.status == 'blocked') {
      _showSnackBar('Your account has been blocked.', isError: true);
      return;
    }

    try {
      final phoneNumber = _phoneController.text.trim();
      if (phoneNumber.isEmpty) {
        _showSnackBar('Phone number is required for payment', isError: true);
        setState(() => _isLoading = false);
        return;
      }

      final paymentResult = await _cartService.processOnlinePayment(
        customerName: _nameController.text.trim(),
        customerEmail: _emailController.text.trim(),
        customerPhone: phoneNumber,
        deliveryAddress: _deliveryType == 'pickup_from_shop' ? _shopAddress : _addressController.text.trim(),
        notes: _notesController.text.trim(),
        gstNumber: ((_currentUser?.isCompany ?? false) || _wantGstInvoice) ? _gstController.text.trim() : null,
        discount: _couponDiscount,
        onPaymentSuccess: (PaymentSuccessResponse response) async {
          final finalAmount = _cartService.grandTotal - _couponDiscount;
          final totalItems = _cartService.cartItems.length;

          final orderResult = await _cartService.createOrderAfterPayment(
            paymentId: response.paymentId ?? '',
            customerName: _nameController.text.trim(),
            customerEmail: _emailController.text.trim(),
            customerPhone: phoneNumber,
            deliveryAddress: _deliveryType == 'pickup_from_shop' ? _shopAddress : _addressController.text.trim(),
            deliveryType: _deliveryType,
            notes: _notesController.text.trim(),
            gstNumber: ((_currentUser?.isCompany ?? false) || _wantGstInvoice) ? _gstController.text.trim() : null,
            discount: _couponDiscount,
          );

          if (orderResult.success && mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => PaymentSuccessScreen(
                  orderId: orderResult.orderId ?? '',
                  amount: finalAmount,
                  itemCount: totalItems,
                ),
              ),
            );
          } else {
            if (mounted) SupabaseService.handleServiceError(context, orderResult.message);
          }
        },
        onPaymentFailure: (PaymentFailureResponse response) async {
          final retry = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentFailureScreen(
                errorCode: response.code.toString(),
                errorMessage: response.message?.toString(),
                amount: _cartService.grandTotal,
              ),
            ),
          );
          if (retry == true) {
            await _processOnlinePayment();
          } else {
            if (mounted) setState(() => _isLoading = false);
          }
        },
        onExternalWallet: (ExternalWalletResponse response) {
          _showSnackBar('External wallet selected: ${response.walletName}', isError: false);
        },
      );

      if (!paymentResult.success) {
        final retry = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentFailureScreen(
              errorMessage: paymentResult.message,
              amount: _cartService.grandTotal,
            ),
          ),
        );
        if (retry == true) {
          await _processOnlinePayment();
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      final retry = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentFailureScreen(
            errorMessage: 'Error processing payment: $e',
            amount: _cartService.grandTotal,
          ),
        ),
      );
      if (retry == true) {
        await _processOnlinePayment();
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _getCouponDescription(CouponModel coupon) {
    final discountText = coupon.discountType == 'percentage'
        ? '${coupon.discountValue.toStringAsFixed(0)}% off'
        : '₹${coupon.discountValue.toStringAsFixed(0)} off';
    final minOrderText = coupon.minOrderValue > 0
        ? ' (min ₹${coupon.minOrderValue.toStringAsFixed(0)})'
        : '';
    return '$discountText$minOrderText';
  }

  bool _isValidGst(String gst) {
    final gstRegex = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}[Z]{1}[0-9A-Z]{1}$');
    return gstRegex.hasMatch(gst);
  }

  Widget _buildAddressSelectionSheet() {
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
                const Text('Select Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _dark)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.close_rounded, size: 18, color: _dark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: const Color(0xFFF1F5F9)),
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
                      Navigator.pop(context);
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
                      foregroundColor: _indigo,
                      side: const BorderSide(color: _indigo),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  );
                }

                final address = _addresses[index];
                final isSelected = _selectedAddress?.id == address.id;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedAddress = address;
                      _addressController.text = address.fullAddress;
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected ? _indigo.withValues(alpha: 0.04) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? _indigo : _slate200,
                        width: isSelected ? 1.5 : 1,
                      ),
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
                                      color: _indigo.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(address.label, style: const TextStyle(color: _indigo, fontWeight: FontWeight.w700, fontSize: 11)),
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
                              Text(address.fullAddress, style: const TextStyle(fontSize: 13, color: _slate500), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(color: _indigo, shape: BoxShape.circle),
                            child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                          ),
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
