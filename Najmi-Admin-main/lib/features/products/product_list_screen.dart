import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'products_provider.dart';
import 'product_model.dart';
import 'dart:async'; // Import for Timer

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalScrollController = ScrollController();
  Timer? _debounceTimer;
  
  // Bulk selection state
  final Set<String> _selectedProductIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    // Initialize controller with current provider value
    _searchController.text = ref.read(productsSearchProvider);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalScrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(productsSearchProvider.notifier).state = value;
      // Reset to first page when searching
      if (value.isNotEmpty) {
        ref.read(productsPageProvider.notifier).state = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(filteredProductsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Search and Add Button Header
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Bulk Actions Button
                if (!_isSelectionMode)
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isSelectionMode = true;
                        _selectedProductIds.clear();
                      });
                    },
                    icon: const Icon(Icons.checklist, size: 18),
                    label: const Text('Bulk Actions'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                      foregroundColor: Colors.grey[700],
                      minimumSize: const Size(140, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                // Bulk Action Toolbar (shown when in selection mode)
                if (_isSelectionMode)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.3)),
                    ),
                    child: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${_selectedProductIds.length} selected',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          tooltip: 'Delete Selected',
                          onPressed: _selectedProductIds.isEmpty ? null : () => _bulkDelete(),
                          color: Colors.red[600],
                        ),
                        IconButton(
                          icon: const Icon(Icons.check_circle_outline, size: 20),
                          tooltip: 'Activate Selected',
                          onPressed: _selectedProductIds.isEmpty ? null : () => _bulkActivate(),
                          color: Colors.green[600],
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel_outlined, size: 20),
                          tooltip: 'Deactivate Selected',
                          onPressed: _selectedProductIds.isEmpty ? null : () => _bulkDeactivate(),
                          color: Colors.orange[600],
                        ),
                        IconButton(
                          icon: const Icon(Icons.percent, size: 20),
                          tooltip: 'Apply Discount',
                          onPressed: _selectedProductIds.isEmpty ? null : () => _bulkDiscount(),
                          color: Colors.blue[600],
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isSelectionMode = false;
                              _selectedProductIds.clear();
                            });
                          },
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ),
                Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Search products by name, ID, brand, category...',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                      prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(productsSearchProvider.notifier).state = '';
                          // Reset to first page when clearing search
                          ref.read(productsPageProvider.notifier).state = 0;
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => context.go('/products/add'),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Add Product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    minimumSize: const Size(140, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
          
          // Table Content
          Expanded(
            child: Stack(
              children: [
                productsAsync.when(
                  data: (products) {
                    if (products.isEmpty) {
                      return const Center(child: Text('No products found matching your search.'));
                    }
                
                // Define constant widths for columns
                const double idWidth = 80;
                const double photoWidth = 60;
                const double brandWidth = 150;
                const double categoryWidth = 120;
                const double subCategoryWidth = 120;
                const double nameWidth = 200;
                const double unitWidth = 80;
                const double stockWidth = 120;
                const double pricingWidth = 120;
                const double priceWidth = 100;
                const double qualityWidth = 120;
                const double descWidth = 200;
                const double hsnWidth = 100;
                const double gstWidth = 80;
                const double actionsWidth = 100;

                const double totalWidth = idWidth + photoWidth + brandWidth + categoryWidth + 
                                        subCategoryWidth + nameWidth + unitWidth + stockWidth + 
                                        pricingWidth + priceWidth + qualityWidth + descWidth + 
                                        hsnWidth + gstWidth + actionsWidth + 60; // + padding

                return Scrollbar(
                  controller: _horizontalScrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  child: SingleChildScrollView(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SizedBox(
                      width: totalWidth,
                      child: Column(
                        children: [
                          // Header Row
                          Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 16),
                                // Checkbox column
                                if (_isSelectionMode)
                                  SizedBox(
                                    width: 50,
                                    child: Checkbox(
                                      value: _selectedProductIds.length == products.length && products.isNotEmpty,
                                      tristate: true,
                                      onChanged: (value) {
                                        setState(() {
                                          if (value == true) {
                                            _selectedProductIds.addAll(products.map((p) => p.id));
                                          } else {
                                            _selectedProductIds.clear();
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                const SizedBox(width: idWidth, child: Text('Product ID', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                                const SizedBox(width: photoWidth, child: Text('Photo', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                                const SizedBox(width: brandWidth, child: Text('Brand', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                                const SizedBox(width: categoryWidth, child: Text('Category', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                                const SizedBox(width: subCategoryWidth, child: Text('Subcategory', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                                const SizedBox(width: nameWidth, child: Text('Product Name', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                                const SizedBox(width: unitWidth, child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                                const SizedBox(width: stockWidth, child: Text('Stock Status', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                                const SizedBox(width: pricingWidth, child: Text('Pricing', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                                const SizedBox(width: priceWidth, child: Text('Price', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                                const SizedBox(width: qualityWidth, child: Text('Quality', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                                const SizedBox(width: descWidth, child: Text('Description', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                                const SizedBox(width: hsnWidth, child: Text('HSN', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                                const SizedBox(width: gstWidth, child: Text('GST %', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                                const SizedBox(width: actionsWidth, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                              ],
                            ),
                          ),
                          
                          // Virtualized List
                          Expanded(
                            child: ListView.separated(
                              itemCount: products.length,
                              separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[200]),
                              itemBuilder: (context, index) {
                                final product = products[index];
                                final isSelected = _selectedProductIds.contains(product.id);
                                return Container(
                                  height: 60,
                                  color: isSelected ? const Color(0xFF4F46E5).withOpacity(0.05) : Colors.white,
                                  child: Row(
                                    children: [
                                      const SizedBox(width: 16),
                                      // Checkbox for selection
                                      if (_isSelectionMode)
                                        SizedBox(
                                          width: 50,
                                          child: Checkbox(
                                            value: isSelected,
                                            onChanged: (value) {
                                              setState(() {
                                                if (value == true) {
                                                  _selectedProductIds.add(product.id);
                                                } else {
                                                  _selectedProductIds.remove(product.id);
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                      SizedBox(width: idWidth, child: Text(product.productId ?? '-', overflow: TextOverflow.ellipsis)),
                                      SizedBox(
                                        width: photoWidth, 
                                        child: Padding(
                                          padding: const EdgeInsets.only(right: 16.0),
                                          child: Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.grey[200]!),
                                            ),
                                            child: (product.photos != null && product.photos!.isNotEmpty)
                                                ? ClipRRect(
                                                    borderRadius: BorderRadius.circular(4),
                                                    child: CachedNetworkImage(
                                                      imageUrl: product.photos![0],
                                                      fit: BoxFit.cover,
                                                      placeholder: (context, url) => Container(color: Colors.grey[100]),
                                                      errorWidget: (context, url, error) => const Icon(Icons.image, size: 20, color: Colors.grey),
                                                    ),
                                                  )
                                                : const Icon(Icons.image, size: 20, color: Colors.grey),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: brandWidth, 
                                        child: Padding(
                                          padding: const EdgeInsets.only(right: 8.0),
                                          child: Text(
                                            product.brandNames.isNotEmpty ? product.brandNames.join(', ') : '-', 
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: categoryWidth, child: Text(product.category ?? '-', overflow: TextOverflow.ellipsis)),
                                      SizedBox(width: subCategoryWidth, child: Text(product.subcategory ?? '-', overflow: TextOverflow.ellipsis)),
                                      SizedBox(
                                        width: nameWidth, 
                                        child: Padding(
                                          padding: const EdgeInsets.only(right: 8.0),
                                          child: Text(
                                            product.productName, 
                                            style: const TextStyle(fontWeight: FontWeight.w500),
                                            overflow: TextOverflow.ellipsis
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: unitWidth, child: Text(product.unit ?? '-')),
                                      SizedBox(
                                        width: stockWidth, 
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: _StockBadge(
                                            status: product.stockStatus,
                                            productId: product.id,
                                            productName: product.productName,
                                          ),
                                        )
                                      ),
                                      SizedBox(width: pricingWidth, child: Text(product.pricingType, overflow: TextOverflow.ellipsis)),
                                      SizedBox(width: priceWidth, child: Text(product.finalPrice?.toString() ?? '-')),
                                      const SizedBox(width: qualityWidth, child: Text('Request...')),
                                      SizedBox(
                                        width: descWidth, 
                                        child: Padding(
                                          padding: const EdgeInsets.only(right: 8.0),
                                          child: Text(product.description ?? '-', overflow: TextOverflow.ellipsis),
                                        )
                                      ),
                                      SizedBox(width: hsnWidth, child: Text(product.hsnNumber ?? '-')),
                                      SizedBox(width: gstWidth, child: Text(product.gstPercent != null ? '${product.gstPercent}%' : '-')),
                                      SizedBox(
                                        width: actionsWidth,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit, size: 18),
                                              color: Colors.blue[600],
                                              onPressed: () => context.go('/products/edit/${product.id}', extra: product),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              tooltip: 'Edit',
                                            ),
                                            const SizedBox(width: 12),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 18),
                                              color: Colors.red[400],
                                              onPressed: () async {
                                                final confirmed = await showDialog<bool>(
                                                  context: context,
                                                  builder: (context) => AlertDialog(
                                                    title: const Text('Delete Product'),
                                                    content: Text('Are you sure you want to delete "${product.productName}"?'),
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

                                                if (confirmed == true && mounted) {
                                                  try {
                                                    await ref.read(productsProvider.notifier).deleteProduct(product.id);
                                                    if (mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(content: Text('Product deleted successfully')),
                                                      );
                                                    }
                                                  } catch (e) {
                                                    if (mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('Error deleting product: $e')),
                                                      );
                                                    }
                                                  }
                                                }
                                              },
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              tooltip: 'Delete',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                ),
                // Pagination controls at bottom right
                Positioned(
                  bottom: 16,
                  right: 24,
                  child: _buildPaginationControls(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Bulk delete products
  Future<void> _bulkDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Products'),
        content: Text('Are you sure you want to delete ${_selectedProductIds.length} products?'),
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

    if (confirmed == true && mounted) {
      try {
        await ref.read(productsProvider.notifier).bulkDeleteProducts(_selectedProductIds.toList());
        if (mounted) {
          setState(() {
            _selectedProductIds.clear();
            _isSelectionMode = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Products deleted successfully'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting products: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // Bulk activate products
  Future<void> _bulkActivate() async {
    try {
      await ref.read(productsProvider.notifier).bulkUpdateStatus(_selectedProductIds.toList(), true);
      if (mounted) {
        setState(() {
          _selectedProductIds.clear();
          _isSelectionMode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Products activated successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error activating products: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Bulk deactivate products
  Future<void> _bulkDeactivate() async {
    try {
      await ref.read(productsProvider.notifier).bulkUpdateStatus(_selectedProductIds.toList(), false);
      if (mounted) {
        setState(() {
          _selectedProductIds.clear();
          _isSelectionMode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Products deactivated successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deactivating products: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Bulk apply discount
  Future<void> _bulkDiscount() async {
    final discountController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply Discount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Apply discount to ${_selectedProductIds.length} products'),
            const SizedBox(height: 16),
            TextField(
              controller: discountController,
              decoration: const InputDecoration(
                labelText: 'Discount Percentage',
                hintText: 'e.g., 10 for 10%',
                suffixText: '%',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final discount = double.tryParse(discountController.text);
      if (discount == null || discount < 0 || discount > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid discount between 0 and 100'), backgroundColor: Colors.red),
        );
        return;
      }

      try {
        await ref.read(productsProvider.notifier).bulkApplyDiscount(_selectedProductIds.toList(), discount);
        if (mounted) {
          setState(() {
            _selectedProductIds.clear();
            _isSelectionMode = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${discount}% discount applied successfully'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error applying discount: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
    
    discountController.dispose();
  }

  Widget _buildPaginationControls() {
    final currentPage = ref.watch(productsPageProvider);
    final totalPagesAsync = ref.watch(productsTotalPagesProvider);
    final searchQuery = ref.watch(productsSearchProvider);

    // Don't show pagination if searching (search results are filtered from current page)
    if (searchQuery.isNotEmpty) {
      return const SizedBox.shrink();
    }

    return totalPagesAsync.when(
      data: (totalPages) {
        if (totalPages <= 1) {
          return const SizedBox.shrink(); // Hide pagination if only one page
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Previous button
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: currentPage > 0
                    ? () {
                        ref.read(productsPageProvider.notifier).state = currentPage - 1;
                        // Scroll to top when changing pages
                        _horizontalScrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: currentPage > 0 ? Colors.blue[600] : Colors.grey[400],
              ),
              const SizedBox(width: 8),
              
              // Page numbers
              ...List.generate(
                totalPages > 5 ? 5 : totalPages, // Show max 5 page numbers
                (index) {
                  int pageNumber;
                  if (totalPages <= 5) {
                    pageNumber = index;
                  } else {
                    // Show pages around current page
                    if (currentPage < 3) {
                      pageNumber = index;
                    } else if (currentPage > totalPages - 4) {
                      pageNumber = totalPages - 5 + index;
                    } else {
                      pageNumber = currentPage - 2 + index;
                    }
                  }

                  final isCurrentPage = pageNumber == currentPage;
                  
                  return GestureDetector(
                    onTap: () {
                      ref.read(productsPageProvider.notifier).state = pageNumber;
                      // Scroll to top when changing pages
                      _horizontalScrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isCurrentPage ? const Color(0xFF4F46E5) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isCurrentPage ? const Color(0xFF4F46E5) : Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${pageNumber + 1}', // Display 1-indexed page number
                          style: TextStyle(
                            color: isCurrentPage ? Colors.white : Colors.grey[700],
                            fontWeight: isCurrentPage ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              // Show ellipsis if there are more pages
              if (totalPages > 5 && currentPage < totalPages - 3)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '...',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
              
              // Show last page if not already visible
              if (totalPages > 5 && currentPage < totalPages - 3)
                GestureDetector(
                  onTap: () {
                    ref.read(productsPageProvider.notifier).state = totalPages - 1;
                    _horizontalScrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: (totalPages - 1) == currentPage ? const Color(0xFF4F46E5) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: (totalPages - 1) == currentPage ? const Color(0xFF4F46E5) : Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$totalPages',
                        style: TextStyle(
                          color: (totalPages - 1) == currentPage ? Colors.white : Colors.grey[700],
                          fontWeight: (totalPages - 1) == currentPage ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              
              const SizedBox(width: 8),
              
              // Next button
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: currentPage < totalPages - 1
                    ? () {
                        ref.read(productsPageProvider.notifier).state = currentPage + 1;
                        // Scroll to top when changing pages
                        _horizontalScrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: currentPage < totalPages - 1 ? Colors.blue[600] : Colors.grey[400],
              ),
              
              const SizedBox(width: 8),
              
              // Page info text
              Text(
                'Page ${currentPage + 1} of $totalPages',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}


class _StockBadge extends ConsumerWidget {
  final String status;
  final String productId;
  final String productName;
  
  const _StockBadge({
    required this.status,
    required this.productId,
    required this.productName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isInStock = status == 'in_stock';
    
    return InkWell(
      onTap: () async {
        try {
          await ref.read(productsProvider.notifier).toggleStockStatus(productId, status);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Stock status updated for "$productName"'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error updating stock status: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isInStock ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isInStock ? const Color(0xFF22C55E).withOpacity(0.2) : const Color(0xFFEF4444).withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isInStock ? Icons.check_circle : Icons.cancel,
              size: 12,
              color: isInStock ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
            ),
            const SizedBox(width: 4),
            Text(
              isInStock ? 'IN STOCK' : 'OUT OF STOCK',
              style: TextStyle(
                color: isInStock ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
