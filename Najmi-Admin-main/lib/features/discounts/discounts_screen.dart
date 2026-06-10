import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import '../products/product_model.dart';

// ── providers ─────────────────────────────────────────────────────────────────

final _allProductsForDiscountProvider = FutureProvider<List<Product>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
      .from('products')
      .select('id, product_id, product_name, category, mrp, final_price, discount_percent, photos, is_active')
      .eq('is_active', true)
      .order('product_name');
  return (response as List).map((j) => Product.fromJson(j)).toList();
});

final _discountSearchProvider = StateProvider<String>((ref) => '');

// ── screen ────────────────────────────────────────────────────────────────────

class DiscountsScreen extends ConsumerStatefulWidget {
  const DiscountsScreen({super.key});

  @override
  ConsumerState<DiscountsScreen> createState() => _DiscountsScreenState();
}

class _DiscountsScreenState extends ConsumerState<DiscountsScreen> {
  final _discountController = TextEditingController();
  final _messageController  = TextEditingController();
  final _searchController   = TextEditingController();

  final Set<String> _selectedIds = {};
  bool _allSelected  = false;
  bool _isSaving     = false;

  @override
  void dispose() {
    _discountController.dispose();
    _messageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Product> _filtered(List<Product> all) {
    final q = ref.read(_discountSearchProvider).toLowerCase().trim();
    if (q.isEmpty) return all;
    return all.where((p) =>
        p.productName.toLowerCase().contains(q) ||
        (p.category ?? '').toLowerCase().contains(q) ||
        (p.productId ?? '').toLowerCase().contains(q)).toList();
  }

  Future<void> _apply(List<Product> allProducts) async {
    final discount = double.tryParse(_discountController.text.trim());
    if (discount == null || discount < 0 || discount > 100) {
      _snack('Enter a valid discount between 0 and 100', isError: true);
      return;
    }
    if (!_allSelected && _selectedIds.isEmpty) {
      _snack('Select at least one product', isError: true);
      return;
    }

    final targets = _allSelected
        ? allProducts
        : allProducts.where((p) => _selectedIds.contains(p.id)).toList();

    setState(() => _isSaving = true);
    try {
      final supabase = ref.read(supabaseProvider);

      // 1. Update product discounts — apply on current final_price (already-discounted price)
      for (final p in targets) {
        // Base = current selling price; fall back to MRP only if no final_price set
        final basePrice = (p.finalPrice != null && p.finalPrice! > 0) ? p.finalPrice! : (p.mrp ?? 0);
        final fp = double.parse((basePrice * (1 - discount / 100)).toStringAsFixed(2));
        
        // Calculate the total effective discount percentage compared to MRP
        double totalDiscountPercent = discount;
        final mrp = p.mrp ?? 0;
        if (mrp > 0) {
          totalDiscountPercent = double.parse((((1 - fp / mrp) * 100).clamp(0, 100)).toStringAsFixed(2));
        }

        await supabase.from('products').update({
          'discount_percent': totalDiscountPercent,
          'final_price'     : fp,
          'updated_at'      : DateTime.now().toIso8601String(),
        }).eq('id', p.id);
      }

      // 2. Build notification message
      final productLabel = _allSelected
          ? 'all products'
          : targets.length == 1
              ? targets.first.productName
              : '${targets.length} products';

      final customMsg = _messageController.text.trim();
      final notifMsg  = customMsg.isNotEmpty
          ? customMsg
          : '🎉 Flash Sale! Get ${discount.toInt()}% off on $productLabel today only!';

      // 3. Fetch all customer user IDs
      final usersResp = await supabase
          .from('users')
          .select('id')
          .eq('role', 'customer');

      final userIds = (usersResp as List).map((u) => u['id'] as String).toList();

      // 4. Insert one notification per user
      final now = DateTime.now().toIso8601String();
      final notifRows = userIds.map((uid) => {
        'user_id'       : uid,
        'type'          : 'other',
        'title'         : '🔥 Discount Alert – ${discount.toInt()}% Off!',
        'message'       : notifMsg,
        'status'        : 'unread',
        'source'        : 'admin',
        'target'        : 'user',
        'sent_by_admin' : true,
        'is_read'       : false,
        'sound_played'  : false,
        'created_at'    : now,
        'updated_at'    : now,
        'metadata'      : {
          'discount_percent': discount,
          'product_count'   : targets.length,
          'product_ids'     : targets.map((p) => p.id).toList(),
          'is_all_products' : _allSelected,
        },
      }).toList();

      // Insert in batches of 500 to stay within payload limits
      const batchSize = 500;
      for (var i = 0; i < notifRows.length; i += batchSize) {
        final batch = notifRows.sublist(
          i, i + batchSize > notifRows.length ? notifRows.length : i + batchSize,
        );
        await supabase.from('notifications').insert(batch);
      }

      // 5. Reset state
      setState(() {
        _selectedIds.clear();
        _allSelected = false;
        _discountController.clear();
        _messageController.clear();
      });

      ref.invalidate(_allProductsForDiscountProvider);
      _snack(
        '✅ ${discount.toInt()}% discount applied to $productLabel and ${userIds.length} users notified!',
      );
    } catch (e) {
      _snack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _removeDiscounts(List<Product> allProducts) async {
    if (!_allSelected && _selectedIds.isEmpty) {
      _snack('Select at least one product first', isError: true);
      return;
    }

    final targets = _allSelected
        ? allProducts
        : allProducts.where((p) => _selectedIds.contains(p.id)).toList();

    // Only products that actually have a discount applied
    final discounted = targets.where((p) => p.mrp != null && p.finalPrice != null && p.finalPrice! < p.mrp!).toList();
    if (discounted.isEmpty) {
      _snack('Selected products have no active discounts to remove', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Discounts'),
        content: Text(
          'This will revert ${discounted.length} product${discounted.length > 1 ? "s" : ""} back to their original MRP price. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            child: const Text('Yes, Revert'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      final supabase = ref.read(supabaseProvider);

      // Revert each product: final_price = mrp, discount_percent = 0
      for (final p in discounted) {
        await supabase.from('products').update({
          'discount_percent': 0,
          'final_price'     : p.mrp,
          'updated_at'      : DateTime.now().toIso8601String(),
        }).eq('id', p.id);
      }

      // Notify users that discounts have ended
      final usersResp = await supabase.from('users').select('id').eq('role', 'customer');
      final userIds = (usersResp as List).map((u) => u['id'] as String).toList();

      final productLabel = _allSelected
          ? 'all products'
          : discounted.length == 1
              ? discounted.first.productName
              : '${discounted.length} products';

      final now = DateTime.now().toIso8601String();
      final notifRows = userIds.map((uid) => {
        'user_id'      : uid,
        'type'         : 'other',
        'title'        : 'Prices Updated',
        'message'      : 'Discount on $productLabel has ended. Prices are back to normal.',
        'status'       : 'unread',
        'source'       : 'admin',
        'target'       : 'user',
        'sent_by_admin': true,
        'is_read'      : false,
        'sound_played' : false,
        'created_at'   : now,
        'updated_at'   : now,
        'metadata'     : {
          'action'        : 'discount_removed',
          'product_count' : discounted.length,
          'product_ids'   : discounted.map((p) => p.id).toList(),
        },
      }).toList();

      const batchSize = 500;
      for (var i = 0; i < notifRows.length; i += batchSize) {
        final end = (i + batchSize) > notifRows.length ? notifRows.length : i + batchSize;
        await supabase.from('notifications').insert(notifRows.sublist(i, end));
      }

      setState(() {
        _selectedIds.clear();
        _allSelected = false;
      });
      ref.invalidate(_allProductsForDiscountProvider);
      _snack('✅ Discounts removed from ${discounted.length} product${discounted.length > 1 ? "s" : ""}. Users notified.');
    } catch (e) {
      _snack('Error removing discounts: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Mathematically reverses a specific admin-applied discount percentage.
  /// original_price = current_final_price / (1 - discountPct/100)
  /// original_discount_pct = (1 - original_price / mrp) * 100
  Future<void> _revertSpecificDiscount(double discountPct) async {
    final multiplier = 1 - discountPct / 100; // e.g. 0.98 for 2%

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFF97316)),
          const SizedBox(width: 8),
          Text('Revert ${discountPct.toInt()}% Discount'),
        ]),
        content: Text(
          'This will mathematically reverse the ${discountPct.toInt()}% discount that was applied from the admin panel.\n\n'
          'Formula: original price = current price ÷ ${multiplier.toStringAsFixed(2)}\n\n'
          'Only products currently showing ${discountPct.toInt()}% discount will be affected.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Revert'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      final supabase = ref.read(supabaseProvider);

      // Fetch only products with this exact discount_percent
      final resp = await supabase
          .from('products')
          .select('id, product_name, mrp, final_price, discount_percent')
          .eq('is_active', true)
          .eq('discount_percent', discountPct);

      final rows = resp as List;
      if (rows.isEmpty) {
        _snack('No products found with ${discountPct.toInt()}% discount.', isError: true);
        return;
      }

      int reverted = 0;
      for (final row in rows) {
        final currentFp = (row['final_price'] as num?)?.toDouble();
        final mrp       = (row['mrp']         as num?)?.toDouble();
        if (currentFp == null || mrp == null || mrp == 0) continue;

        // Reverse the discount math
        final originalFp = double.parse((currentFp / multiplier).toStringAsFixed(2));

        // Recalculate what the original discount_percent was relative to MRP
        final originalDiscPct = double.parse(
          (((1 - originalFp / mrp) * 100).clamp(0, 100)).toStringAsFixed(2),
        );

        await supabase.from('products').update({
          'final_price'     : originalFp,
          'discount_percent': originalDiscPct,
          'updated_at'      : DateTime.now().toIso8601String(),
        }).eq('id', row['id']);
        reverted++;
      }

      ref.invalidate(_allProductsForDiscountProvider);
      _snack('✅ Reverted ${discountPct.toInt()}% discount from $reverted products. Prices restored.');
    } catch (e) {
      _snack('Error reverting: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Restores featured products to a given discount % off their MRP.
  /// e.g. discountPct=31 → final_price = mrp * 0.69
  Future<void> _restoreFeaturedDiscounts(double discountPct) async {
    setState(() => _isSaving = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final multiplier = 1 - discountPct / 100;

      // 1. Get all active featured product IDs
      final featResp = await supabase
          .from('featured_products')
          .select('product_id')
          .eq('is_active', true);

      final featIds = (featResp as List)
          .map((r) => r['product_id'] as String)
          .toList();

      if (featIds.isEmpty) {
        _snack('No active featured products found.', isError: true);
        return;
      }

      // 2. Fetch their MRP
      final prodResp = await supabase
          .from('products')
          .select('id, product_name, mrp')
          .eq('is_active', true)
          .inFilter('id', featIds);

      final products = prodResp as List;
      int updated = 0;

      for (final p in products) {
        final mrp = (p['mrp'] as num?)?.toDouble();
        if (mrp == null || mrp == 0) continue;

        final newFp = double.parse((mrp * multiplier).toStringAsFixed(2));
        await supabase.from('products').update({
          'final_price'     : newFp,
          'discount_percent': discountPct,
          'updated_at'      : DateTime.now().toIso8601String(),
        }).eq('id', p['id']);
        updated++;
      }

      ref.invalidate(_allProductsForDiscountProvider);
      _snack('✅ Restored ${discountPct.toInt()}% discount on $updated featured products.');
    } catch (e) {
      _snack('Error restoring featured discounts: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red[700] : const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
    ));
  }


  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(_allProductsForDiscountProvider);
    final searchQuery   = ref.watch(_discountSearchProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (allProducts) {
          final filtered = _filtered(allProducts);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Left: product picker ─────────────────────────────────────
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _buildProductPickerHeader(allProducts, filtered, searchQuery),
                    Expanded(child: _buildProductList(filtered)),
                  ],
                ),
              ),

              // ── Right: discount form ─────────────────────────────────────
              Container(
                width: 340,
                margin: const EdgeInsets.all(24),
                child: _buildDiscountForm(allProducts, filtered),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── product picker header ──────────────────────────────────────────────────

  Widget _buildProductPickerHeader(
    List<Product> all,
    List<Product> filtered,
    String searchQuery,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 24, 0, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, color: Color(0xFF6366F1)),
              const SizedBox(width: 8),
              const Text(
                'Select Products',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const Spacer(),
              if (!_allSelected)
                Text(
                  '${_selectedIds.length} selected',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // "All Products" toggle
          InkWell(
            onTap: () => setState(() {
              _allSelected = !_allSelected;
              if (_allSelected) _selectedIds.clear();
            }),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _allSelected
                    ? const Color(0xFF6366F1).withOpacity(0.08)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _allSelected ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _allSelected ? Icons.check_box : Icons.check_box_outline_blank,
                    color: _allSelected ? const Color(0xFF6366F1) : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Apply to ALL products',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${all.length} products',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Search
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              hintText: 'Search by name, category or ID…',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(_discountSearchProvider.notifier).state = '';
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onChanged: (v) => ref.read(_discountSearchProvider.notifier).state = v,
          ),
        ],
      ),
    );
  }

  // ── product list ───────────────────────────────────────────────────────────

  Widget _buildProductList(List<Product> products) {
    if (products.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 0, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
        ),
        child: const Center(
          child: Text('No products found', style: TextStyle(color: Color(0xFF94A3B8))),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 0, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: products.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
        itemBuilder: (context, i) {
          final p = products[i];
          final isSelected = _allSelected || _selectedIds.contains(p.id);

          return InkWell(
            onTap: _allSelected
                ? null
                : () => setState(() {
                      if (_selectedIds.contains(p.id)) {
                        _selectedIds.remove(p.id);
                      } else {
                        _selectedIds.add(p.id);
                      }
                    }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              color: isSelected
                  ? const Color(0xFF6366F1).withOpacity(0.05)
                  : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // checkbox
                  Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFCBD5E1),
                    size: 20,
                  ),
                  const SizedBox(width: 12),

                  // thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: (p.photos != null && p.photos!.isNotEmpty)
                        ? Image.network(
                            p.photos!.first,
                            width: 40, height: 40, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder(),
                          )
                        : _placeholder(),
                  ),
                  const SizedBox(width: 12),

                  // name + category
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.productName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (p.category != null)
                          Text(
                            p.category!,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                      ],
                    ),
                  ),

                  // price info — show current selling price; strike MRP only if different
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Show MRP struck-through only when there's already a discount
                      if (p.mrp != null && p.finalPrice != null && p.finalPrice! < p.mrp!)
                        Text(
                          'MRP ₹${p.mrp!.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      // Current selling price — this is what the NEW discount applies on
                      Text(
                        '₹${(p.finalPrice ?? p.mrp ?? 0).toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      Text(
                        'selling price',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.image_outlined, size: 20, color: Color(0xFFCBD5E1)),
      );

  // ── discount form ──────────────────────────────────────────────────────────

  Widget _buildDiscountForm(List<Product> allProducts, List<Product> filtered) {
    final targetCount = _allSelected ? allProducts.length : _selectedIds.length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.local_offer_rounded, color: Colors.white, size: 32),
                const SizedBox(height: 12),
                const Text(
                  'Apply Discount',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Notifies all app users instantly',
                  style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Target summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF6366F1), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Target', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                      Text(
                        _allSelected
                            ? 'All ${allProducts.length} active products'
                            : targetCount == 0
                                ? 'No products selected'
                                : '$targetCount product${targetCount > 1 ? "s" : ""} selected',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: targetCount > 0 ? const Color(0xFF1E293B) : const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Discount % input
          _label('Discount Percentage *'),
          const SizedBox(height: 6),
          TextField(
            controller: _discountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: 'e.g. 15',
              suffixText: '%',
              suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),

          const SizedBox(height: 16),

          // Quick discount chips
          _label('Quick Select'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [5, 10, 15, 20, 25, 30].map((v) {
              final isActive = _discountController.text == '$v';
              return ChoiceChip(
                label: Text('$v%'),
                selected: isActive,
                onSelected: (_) {
                  setState(() => _discountController.text = '$v');
                },
                selectedColor: const Color(0xFF6366F1),
                labelStyle: TextStyle(
                  color: isActive ? Colors.white : const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                backgroundColor: const Color(0xFFF1F5F9),
                side: BorderSide(
                  color: isActive ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Custom message
          _label('Custom Notification Message (optional)'),
          const SizedBox(height: 6),
          TextField(
            controller: _messageController,
            maxLines: 3,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: 'Leave empty to use default message',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),

          const SizedBox(height: 8),

          // Preview
          if (_discountController.text.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE0E7FF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.preview_outlined, size: 14, color: Color(0xFF6366F1)),
                      SizedBox(width: 4),
                      Text('Notification Preview',
                          style: TextStyle(fontSize: 11, color: Color(0xFF6366F1), fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _buildPreviewMsg(allProducts),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          // Apply button
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : () => _apply(allProducts),
              icon: _isSaving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _isSaving ? 'Applying…' : 'Apply & Notify Users',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Info note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: Color(0xFFF97316)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Discount applies on the current selling price (final_price), not MRP.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Remove Discounts section ────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFECACA)),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.remove_circle_outline, color: Color(0xFFEF4444), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Remove Discounts',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Reverts selected products back to their MRP. Resets discount_percent to 0 and final_price to MRP.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : () => _removeDiscounts(allProducts),
                    icon: const Icon(Icons.restore, size: 18),
                    label: const Text(
                      'Revert to MRP',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Emergency: Revert a specific % wrongly applied ───────────────
          _EmergencyRevertCard(isSaving: _isSaving, onRevert: _revertSpecificDiscount),

          const SizedBox(height: 16),

          // ── Restore Featured Products discount ───────────────────────────
          _FeaturedRestoreCard(isSaving: _isSaving, onRestore: _restoreFeaturedDiscounts),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _buildPreviewMsg(List<Product> all) {
    final d = _discountController.text.trim();
    if (_messageController.text.trim().isNotEmpty) return _messageController.text.trim();
    final count = _allSelected ? all.length : _selectedIds.length;
    final label = _allSelected ? 'all products' : count == 1
        ? all.firstWhere((p) => _selectedIds.contains(p.id), orElse: () => all.first).productName
        : '$count products';
    return '🎉 Flash Sale! Get $d% off on $label today only!';
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
      );
}

// ── Emergency Revert Widget ───────────────────────────────────────────────────

class _EmergencyRevertCard extends StatefulWidget {
  final bool isSaving;
  final Future<void> Function(double) onRevert;

  const _EmergencyRevertCard({required this.isSaving, required this.onRevert});

  @override
  State<_EmergencyRevertCard> createState() => _EmergencyRevertCardState();
}

class _EmergencyRevertCardState extends State<_EmergencyRevertCard> {
  final _ctrl = TextEditingController(text: '2');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCD34D)),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Emergency: Reverse Admin Discount',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'If a discount was mistakenly applied via this panel, enter the exact % and revert it. '
            'This uses reverse math to restore original prices.',
            style: TextStyle(fontSize: 12, color: Color(0xFF78716C)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    hintText: 'e.g. 2',
                    suffixText: '%',
                    labelText: 'Discount % to reverse',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFFCD34D)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFFCD34D)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: widget.isSaving
                      ? null
                      : () {
                          final pct = double.tryParse(_ctrl.text.trim());
                          if (pct == null || pct <= 0 || pct >= 100) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Enter a valid percentage (1–99)'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          widget.onRevert(pct);
                        },
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  label: const Text('Revert', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Featured Products Restore Widget ─────────────────────────────────────────

class _FeaturedRestoreCard extends StatefulWidget {
  final bool isSaving;
  final Future<void> Function(double) onRestore;

  const _FeaturedRestoreCard({required this.isSaving, required this.onRestore});

  @override
  State<_FeaturedRestoreCard> createState() => _FeaturedRestoreCardState();
}

class _FeaturedRestoreCardState extends State<_FeaturedRestoreCard> {
  final _ctrl = TextEditingController(text: '31');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF86EFAC)),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.star_rounded, color: Color(0xFF16A34A), size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Restore Featured Products Discount',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Sets all active featured products to a specific discount % from their MRP. '
            'Default is 31% — adjust if needed.',
            style: TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    hintText: 'e.g. 31',
                    suffixText: '% off MRP',
                    labelText: 'Discount %',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF86EFAC)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF86EFAC)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF16A34A), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: widget.isSaving
                      ? null
                      : () {
                          final pct = double.tryParse(_ctrl.text.trim());
                          if (pct == null || pct <= 0 || pct >= 100) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Enter a valid percentage (1–99)'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          widget.onRestore(pct);
                        },
                  icon: const Icon(Icons.star_rounded, size: 18),
                  label: const Text('Restore', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
