import 'package:flutter/material.dart';
import 'package:contracto_app/shared/widgets/custom_network_image.dart';
import 'package:provider/provider.dart';
import 'package:contracto_app/features/quotations/data/services/quote_request_cart_service.dart';
import 'package:contracto_app/features/quotations/data/services/quotation_service.dart';
import 'package:contracto_app/features/products/data/services/unit_service.dart';
import 'package:contracto_app/features/credit/data/services/business_credit_service.dart';
import 'package:contracto_app/features/address/data/models/address_model.dart';
import 'package:contracto_app/features/address/data/services/address_service.dart';
import 'package:contracto_app/features/address/presentation/screens/address_screen.dart';

class QuoteRequestCartScreen extends StatefulWidget {
  const QuoteRequestCartScreen({super.key});

  @override
  State<QuoteRequestCartScreen> createState() => _QuoteRequestCartScreenState();
}

class _QuoteRequestCartScreenState extends State<QuoteRequestCartScreen> {
  final TextEditingController _globalNotesController = TextEditingController();
  final UnitService _unitService = UnitService();
  final AddressService _addressService = AddressService();
  List<UnitModel> _availableUnits = [];
  List<AddressModel> _addresses = [];
  AddressModel? _selectedAddress;
  bool _isLoadingAddresses = true;
  bool _isSubmitting = false;
  String _deliveryType = 'home_delivery'; // 'home_delivery' or 'pickup_from_shop'

  // Najmi shop address shown for pickup
  static const _shopAddress =
      'Najmi Electricals and Hardware, Dr Ambedkar Road, Shivaji Chowk, '
      'Kalyan West, near pathare nursery, Kalyan, Maharashtra 421301';

  @override
  void initState() {
    super.initState();
    _loadUnits();
    _loadAddresses();
  }

  Future<void> _loadUnits() async {
    try {
      final units = await _unitService.getUnits();
      if (mounted) {
        setState(() {
          _availableUnits = units;
        });
      }
    } catch (e) {
      print('Error loading units: $e');
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
          _isLoadingAddresses = false;
        });
      }
    } catch (e) {
      print('Error loading addresses: $e');
      if (mounted) setState(() => _isLoadingAddresses = false);
    }
  }

  @override
  void dispose() {
    _globalNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<QuoteRequestCartService>(
      builder: (context, cart, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Quote Request Cart'),
            actions: [
              if (cart.itemCount > 0)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${cart.itemCount} ${cart.itemCount == 1 ? 'item' : 'items'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: cart.isEmpty
              ? _buildEmptyCart()
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Cart Items
                          ...cart.items.entries.map((entry) {
                            return _buildCartItem(entry.key, entry.value, cart);
                          }),
                          
                          const SizedBox(height: 24),
                          
                          // Delivery Type Section
                          _buildDeliveryTypeSection(),

                          const SizedBox(height: 16),

                          // Address / Pickup Section
                          _buildAddressSection(),
                          
                          const SizedBox(height: 24),
                          
                          // Summary Section
                          _buildSummarySection(cart),
                          
                          const SizedBox(height: 24),
                          
                          // Global Notes Section
                          _buildNotesSection(),
                          
                          const SizedBox(height: 100), // Space for fixed button
                        ],
                      ),
                    ),
                  ],
                ),
          bottomNavigationBar: cart.isEmpty
              ? null
              : _buildSubmitButton(cart),
        );
      },
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 120,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          Text(
            'Your quote cart is empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add products to request quotes',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate directly to Home tab (index 0)
              Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
                '/main',
                (route) => false,
                arguments: 0,
              );
            },
            icon: const Icon(Icons.shopping_bag_outlined),
            label: const Text('Browse Products'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(String key, QuoteRequestItem item, QuoteRequestCartService cart) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[200],
                    child: item.product.photos.first.isNotEmpty
                        ? CustomNetworkImage(
                            imageUrl: item.product.photos.first,
                            fit: BoxFit.cover,
                            errorWidget: Icon(Icons.image, size: 40, color: Colors.grey[400]),
                          )
                        : Icon(Icons.image, size: 40, color: Colors.grey[400]),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Product Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.productName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (item.brandName != null)
                        Text(
                          'Brand: ${item.brandName}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.qualityOptionName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Remove Button
                IconButton(
                  onPressed: () => _confirmRemoveItem(key, cart),
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red,
                  tooltip: 'Remove',
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
                  // Quantity Controls
                  Row(
                    children: [
                      Text(
                        'Quantity:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                      const Spacer(),
                      if (item.unit != 'pieces' && item.unit != 'units' && item.unit != 'nos') ...[
                         // For measurable units, just show the quantity (editable in details screen)
                         // Getting precision right for display
                         // For measurable units, show quantity and unit dropdown
                         // Getting precision right for display
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[50], 
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: item.quantity > 1
                                      ? () => cart.updateQuantity(key, item.quantity - 1)
                                      : null,
                                  icon: const Icon(Icons.remove, size: 20),
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Row(
                                    children: [
                                      Text(
                                        item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 2),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Unit Dropdown
                                      if (_availableUnits.isNotEmpty)
                                        Container(
                                          height: 32,
                                          padding: const EdgeInsets.only(left: 8),
                                          decoration: BoxDecoration(
                                            border: Border(left: BorderSide(color: Colors.grey[300]!)),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: _availableUnits.any((u) => u.code == item.unit) ? item.unit : null,
                                              hint: Text(item.unit),
                                              icon: const Icon(Icons.arrow_drop_down, size: 20),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                              onChanged: (String? newUnitCode) {
                                                if (newUnitCode != null) {
                                                  final newUnit = _availableUnits.firstWhere(
                                                    (u) => u.code == newUnitCode,
                                                    orElse: () => _availableUnits.first,
                                                  );
                                                  cart.updateUnit(key, newUnit.code, newUnit.name);
                                                }
                                              },
                                              items: _availableUnits.map((UnitModel unit) {
                                                return DropdownMenuItem<String>(
                                                  value: unit.code,
                                                  child: Text(unit.code),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        )
                                      else
                                        Text(
                                          item.unit,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => cart.updateQuantity(key, item.quantity + 1),
                                  icon: const Icon(Icons.add, size: 20),
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                ),
                              ],
                            ),
                          ),
                      ] else ...[
                        // For discrete units, keep +/- buttons
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: item.quantity > 1
                                    ? () => cart.updateQuantity(key, item.quantity - 1)
                                    : null,
                                icon: const Icon(Icons.remove, size: 20),
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  item.quantity.toStringAsFixed(0),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => cart.updateQuantity(key, item.quantity + 1),
                                icon: const Icon(Icons.add, size: 20),
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  
                  // Item Notes
                  if (item.notes != null && item.notes!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.note_outlined, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.notes!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        Widget _buildSummarySection(QuoteRequestCartService cart) {
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryRow('Total Products', '${cart.itemCount}'),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Total Quantity', cart.totalItems.toStringAsFixed(cart.totalItems.truncateToDouble() == cart.totalItems ? 0 : 2)),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Estimated Delivery', '24-48 hrs', isHighlight: true),
                ],
              ),
            ),
          );
        }

        Widget _buildSummaryRow(String label, String value, {bool isHighlight = false}) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isHighlight ? FontWeight.w600 : FontWeight.w500,
                  color: isHighlight ? Theme.of(context).colorScheme.primary : Colors.black87,
                ),
              ),
            ],
          );
        }

        Widget _buildDeliveryTypeSection() {
          final primary = Theme.of(context).colorScheme.primary;
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Delivery Type',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _deliveryType = 'home_delivery'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _deliveryType == 'home_delivery'
                                  ? primary.withValues(alpha: 0.06)
                                  : Colors.white,
                              border: Border.all(
                                color: _deliveryType == 'home_delivery' ? primary : Colors.grey.shade300,
                                width: _deliveryType == 'home_delivery' ? 1.5 : 1,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.home_rounded,
                                    color: _deliveryType == 'home_delivery' ? primary : Colors.grey,
                                    size: 24),
                                const SizedBox(height: 6),
                                Text(
                                  'Home Delivery',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _deliveryType == 'home_delivery' ? primary : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _deliveryType = 'pickup_from_shop'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _deliveryType == 'pickup_from_shop'
                                  ? primary.withValues(alpha: 0.06)
                                  : Colors.white,
                              border: Border.all(
                                color: _deliveryType == 'pickup_from_shop' ? primary : Colors.grey.shade300,
                                width: _deliveryType == 'pickup_from_shop' ? 1.5 : 1,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.storefront_rounded,
                                    color: _deliveryType == 'pickup_from_shop' ? primary : Colors.grey,
                                    size: 24),
                                const SizedBox(height: 6),
                                Text(
                                  'Pick up from Shop',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _deliveryType == 'pickup_from_shop' ? primary : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        Widget _buildAddressSection() {
          if (_deliveryType == 'pickup_from_shop') {
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pickup Address',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('Shop', style: TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.w700, fontSize: 11)),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('Pickup Point', style: TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.w700, fontSize: 11)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            _shopAddress,
                            style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                    ),
                  ],
                ),
              ),
            );
          }

          // Home delivery — show address selector
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Delivery Address',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      if (_addresses.isNotEmpty)
                        GestureDetector(
                          onTap: _showAddressSelectionSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Change',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingAddresses)
                    const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  else if (_selectedAddress != null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _selectedAddress!.label,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
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
                                  child: const Text('Default', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w700, fontSize: 11)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _selectedAddress!.fullAddress,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: [
                        Text('No saved addresses found', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
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
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        }

        void _showAddressSelectionSheet() {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => _buildAddressSelectionSheet(ctx),
          );
        }

        Widget _buildAddressSelectionSheet(BuildContext ctx) {
          return Container(
            margin: EdgeInsets.only(top: MediaQuery.of(ctx).padding.top + 50),
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
                      const Text('Select Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.close_rounded, size: 18),
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
                            Navigator.pop(ctx);
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
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        );
                      }
                      final address = _addresses[index];
                      final isSelected = _selectedAddress?.id == address.id;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedAddress = address);
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.04)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade200,
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
                                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(address.label, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 11)),
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
                              if (isSelected)
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
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

        Widget _buildNotesSection() {
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Additional Notes (Optional)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _globalNotesController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Add any special requirements or notes...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        Widget _buildSubmitButton(QuoteRequestCartService cart) {
          return SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                
              ),
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : () => _submitQuoteRequest(cart),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Submit Quote Request',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          );
        }

        void _confirmRemoveItem(String key, QuoteRequestCartService cart) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Remove Item'),
              content: const Text('Are you sure you want to remove this item from your quote request?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    cart.removeItem(key);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Item removed from cart'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Remove'),
                ),
              ],
            ),
          );
        }

        Future<void> _submitQuoteRequest(QuoteRequestCartService cart) async {
          if (_isSubmitting) return;
          setState(() => _isSubmitting = true);

          try {
            // Validate address for home delivery
          if (_deliveryType == 'home_delivery' && _selectedAddress == null) {
            setState(() => _isSubmitting = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please add a delivery address before submitting your quote request.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 3),
                ),
              );
            }
            return;
          }

          // Check if account is frozen
            final creditService = BusinessCreditService();
            final isFrozen = await creditService.isAccountFrozen();
            if (isFrozen) {
              setState(() => _isSubmitting = false);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Your account is frozen due to overdue payment. Please clear pending dues first to place new orders.'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 4),
                  ),
                );
              }
              return;
            }

            print('========================================');
            print('SUBMITTING QUOTE REQUEST');
            print('========================================');
            
            final quotationService = QuotationService();
            final globalNotes = _globalNotesController.text.trim();
          final deliveryAddress = _deliveryType == 'pickup_from_shop'
              ? _shopAddress
              : (_selectedAddress?.fullAddress ?? '');

            print('Cart has ${cart.itemCount} products with ${cart.totalItems} total items');

            // Prepare all items for the quote request
            final allItems = cart.itemsList.map((item) {
              return {
                'quality_option_id': item.qualityOptionId,
                'quality_option_name': item.qualityOptionName,
                'quantity': item.quantity,
                'unit': item.unit, // Use real unit code
                'unit_name': item.unitName, // Added unit name for clarity/backend usage if needed
                'brand_id': item.brandId,
                'brand_name': item.brandName,
                'product_id': item.product.id,
                'product_name': item.product.productName,
                'category': item.product.category,
                'notes': item.notes,
              };
            }).toList();

      print('Prepared ${allItems.length} items for submission');

      // Get the first item's details for the main quote request
      final firstItem = cart.itemsList.first;
      
      // Combine all individual notes with global notes
      final allNotes = [
        if (globalNotes.isNotEmpty) 'General Notes: $globalNotes',
        ...cart.itemsList.where((item) => item.notes != null && item.notes!.isNotEmpty)
            .map((item) => '${item.product.productName}: ${item.notes}'),
      ].join('\n\n');

        final quotationData = {
        'product_id': firstItem.product.id,
        'product_name': 'Quote Request - ${cart.itemCount} products, ${cart.totalItems} items',
        'category': firstItem.product.category,
        'brand_id': firstItem.brandId,
        'notes': allNotes.isNotEmpty ? allNotes : null,
        'delivery_address': deliveryAddress,
        'items': allItems,
      };

      print('Quotation data prepared:');
      print('  Product ID: ${quotationData['product_id']}');
      print('  Product Name: ${quotationData['product_name']}');
      print('  Category: ${quotationData['category']}');
      print('  Brand ID: ${quotationData['brand_id']}');
      print('  Items count: ${allItems.length}');

      // Create a single consolidated quote request with all items
      print('Calling quotationService.createQuotation...');
      await quotationService.createQuotation(quotationData);
      print('Quote request created successfully!');
      print('========================================');

      // Clear cart
      cart.clear();

      if (mounted) {
        setState(() => _isSubmitting = false);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quote request submitted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Navigate directly to the Quotes tab (index 1)
        Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
          '/main',
          (route) => false,
          arguments: 1,
        );
      }
    } catch (e, stackTrace) {
      print('========================================');
      print('ERROR SUBMITTING QUOTE REQUEST');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      print('========================================');
      
      if (mounted) {
        setState(() => _isSubmitting = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit quote request: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
