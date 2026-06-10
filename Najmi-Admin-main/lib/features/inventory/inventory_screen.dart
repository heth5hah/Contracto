import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../categories/categories_notifier_provider.dart';
import '../categories/category_model.dart';
import '../categories/add_edit_category_dialog.dart';
import 'inventory_provider.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String? _selectedCategory;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedProductIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with back button when viewing category
            Row(
              children: [
                if (_selectedCategory != null) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(() {
                      _selectedCategory = null;
                      _searchQuery = '';
                      _searchController.clear();
                    }),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  _selectedCategory == null ? Icons.inventory_2 : Icons.category,
                  size: 32,
                  color: Colors.blueGrey,
                ),
                const SizedBox(width: 12),
                Text(
                  _selectedCategory == null 
                      ? 'Inventory Management' 
                      : 'Inventory: $_selectedCategory',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: () {
                    ref.invalidate(categoriesNotifierProvider);
                    ref.invalidate(inventoryListProvider);
                  },
                ),
                if (_selectedCategory == null) ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showAddCategoryDialog(context),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Add Category', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      minimumSize: const Size(140, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _selectedCategory == null
                  ? 'Select a category to manage stock levels for products.'
                  : 'Add or remove stock when inventory arrives or products are sold.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            
            // Show either category grid or product list
            Expanded(
              child: _selectedCategory == null
                  ? _buildCategoryGrid()
                  : _buildProductList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddEditCategoryDialog(),
    );
  }

  Widget _buildCategoryGrid() {
    final categoriesAsync = ref.watch(categoriesNotifierProvider);
    final inventoryAsync = ref.watch(inventoryListProvider);

    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.category_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'No categories found',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        // Get inventory data to calculate stock per category
        final inventoryItems = inventoryAsync.valueOrNull ?? [];

        // Calculate stock counts per category with normalization
        Map<String, int> categoryStockCounts = {};
        Map<String, int> categoryInStockCounts = {};
        
        for (final product in inventoryItems) {
          final rawCat = product['category']?.toString() ?? '';
          final categoryKey = _normalizeCategoryName(rawCat);
          if (categoryKey.isEmpty) continue;
          
          final variants = (product['variants'] as List<dynamic>? ?? []);
          categoryStockCounts[categoryKey] = (categoryStockCounts[categoryKey] ?? 0) + variants.length;
          
          for (final variant in variants) {
            final hasInventory = variant['has_inventory_entry'] == true;
            final stock = ((variant['current_stock'] ?? 0) as num).toInt();
            bool isInStock = hasInventory ? stock > 0 : stock == -1;
            if (isInStock) {
              categoryInStockCounts[categoryKey] = (categoryInStockCounts[categoryKey] ?? 0) + 1;
            }
          }
        }

        // Deduplicate category list from DB for display
        final Set<String> seenNormalized = {};
        final List<Category> uniqueCategories = [];
        for (final cat in categories) {
          final norm = _normalizeCategoryName(cat.name);
          if (!seenNormalized.contains(norm)) {
            uniqueCategories.add(cat);
            seenNormalized.add(norm);
          }
        }

        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.0,
          ),
          itemCount: uniqueCategories.length,
          itemBuilder: (context, index) {
            final category = uniqueCategories[index];
            final categoryKey = _normalizeCategoryName(category.name);
            final inStockCount = categoryInStockCounts[categoryKey] ?? 0;
            final totalCount = categoryStockCounts[categoryKey] ?? category.productCount;
            return _buildCategoryCard(category, inStockCount, totalCount);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text('Error: $e', style: TextStyle(color: Colors.red.shade600)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: () => ref.invalidate(categoriesNotifierProvider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(Category category, int inStockCount, int totalCount) {
    // Category icons based on name
    IconData icon = Icons.category;
    Color color = Colors.blue;
    
    final name = category.name.toLowerCase();
    if (name.contains('plumb')) {
      icon = Icons.plumbing;
      color = Colors.blue;
    } else if (name.contains('build') || name.contains('material')) {
      icon = Icons.construction;
      color = Colors.orange;
    } else if (name.contains('bath') || name.contains('faucet')) {
      icon = Icons.bathtub;
      color = Colors.teal;
    } else if (name.contains('electric')) {
      icon = Icons.electrical_services;
      color = Colors.amber;
    } else if (name.contains('paint')) {
      icon = Icons.format_paint;
      color = Colors.purple;
    } else if (name.contains('tool')) {
      icon = Icons.build;
      color = Colors.brown;
    } else if (name.contains('hardware')) {
      icon = Icons.hardware;
      color = Colors.indigo;
    }

    // Determine stock health color
    Color stockColor;
    if (totalCount == 0) {
      stockColor = Colors.grey;
    } else if (inStockCount == 0) {
      stockColor = Colors.red;
    } else if (inStockCount < totalCount / 2) {
      stockColor = Colors.orange;
    } else {
      stockColor = Colors.green;
    }

    return Stack(
      children: [
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _selectedCategory = category.name),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 36, color: color),
                ),
                const SizedBox(height: 10),
                Text(
                  category.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                // Total products
                Text(
                  '${category.productCount} products',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                // In Stock badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: stockColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: stockColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2, size: 12, color: stockColor),
                      const SizedBox(width: 4),
                      Text(
                        '$inStockCount in stock',
                        style: TextStyle(
                          color: stockColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
        // Delete button in the top right
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _showDeleteCategoryConfirmation(context, category),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showDeleteCategoryConfirmation(BuildContext context, Category category) {
    final hasProducts = category.productCount > 0;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Category: ${category.name}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this category? This action cannot be undone.'),
            if (hasProducts) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This category contains ${category.productCount} products. You must move or delete these products before deleting the category.',
                        style: TextStyle(color: Colors.red.shade900, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: hasProducts ? null : () async {
              Navigator.pop(context);
              try {
                await ref.read(categoriesNotifierProvider.notifier).deleteCategory(category.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Category deleted successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: hasProducts ? Colors.grey : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    final inventoryAsync = ref.watch(inventoryListProvider);

    return Column(
      children: [
        Row(
          children: [
            // Search bar
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                ),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: () => context.go('/products/add?category=${Uri.encodeComponent(_selectedCategory!)}'),
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
        const SizedBox(height: 16),
        
        // Product table
        Expanded(
          child: inventoryAsync.when(
            data: (products) {
              // Filter by category and search
              final filteredProducts = products.where((p) {
                final category = _normalizeCategoryName(p['category']?.toString() ?? '');
                final productName = (p['product_name']?.toString() ?? '').toLowerCase();
                final brand = (p['brand_name']?.toString() ?? '').toLowerCase();
                
                final matchesCategory = category == _normalizeCategoryName(_selectedCategory!);
                final matchesSearch = _searchQuery.isEmpty ||
                    productName.contains(_searchQuery) ||
                    brand.contains(_searchQuery);
                
                return matchesCategory && matchesSearch;
              }).toList();

              if (filteredProducts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty 
                            ? 'No products match your search' 
                            : 'No products found in this category',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  // Summary counts
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryChip('Products', filteredProducts.length.toString(), Colors.blue),
                        _buildSummaryChip(
                          'In Stock', 
                          filteredProducts.fold(0, (sum, p) => 
                            sum + (p['variants'] as List).where((v) => ((v['current_stock'] as num).toInt()) > 0 || ((v['current_stock'] as num).toInt()) == -1).length
                          ).toString(), 
                          Colors.green
                        ),
                        _buildSummaryChip(
                          'Out of Stock', 
                          filteredProducts.fold(0, (sum, p) => 
                            sum + (p['variants'] as List).where((v) => ((v['current_stock'] as num).toInt()) == 0).length
                          ).toString(), 
                          Colors.red
                        ),
                      ],
                    ),
                  ),
                  
                  // Product & Variant List
                  Expanded(
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      clipBehavior: Clip.antiAlias,
                      child: ListView.separated(
                        itemCount: filteredProducts.length,
                        separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (context, index) {
                          final product = filteredProducts[index] as Map<String, dynamic>;
                          final productId = product['id']?.toString() ?? '';
                          final variants = (product['variants'] as List<dynamic>? ?? []);
                          final isExpanded = _expandedProductIds.contains(productId);
                          final brandName = product['brand_name']?.toString() ?? '-';
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Product Main Row
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    if (isExpanded) {
                                      _expandedProductIds.remove(productId);
                                    } else {
                                      _expandedProductIds.add(productId);
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                  color: isExpanded ? Colors.blue.withOpacity(0.04) : null,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product['product_name']?.toString() ?? 'Unknown',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: isExpanded ? Colors.blue.shade900 : null,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Brand: $brandName',
                                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '${variants.length} Variants',
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          children: [
                                            _getProductStatusBadge(variants),
                                            const SizedBox(width: 8),
                                            // Toggle Product Stock Status
                                            Tooltip(
                                              message: product['stock_status'] == 'out_of_stock' ? 'Mark as In Stock' : 'Mark Out of Stock',
                                              child: Switch(
                                                value: product['stock_status'] != 'out_of_stock',
                                                activeColor: Colors.green,
                                                onChanged: (val) async {
                                                  try {
                                                    await ref.read(inventoryServiceProvider).toggleProductStockStatus(
                                                      productId,
                                                      product['stock_status'],
                                                    );
                                                    ref.invalidate(inventoryListProvider);
                                                  } catch (e) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
                                                    );
                                                  }
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        isExpanded ? Icons.expand_less : Icons.expand_more,
                                        color: Colors.blueGrey,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              // Variants List (shown when expanded)
                              if (isExpanded)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.only(left: 32, right: 16, bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50.withOpacity(0.5),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: Row(
                                          children: const [
                                             Expanded(flex: 3, child: Text('QUALITY OPTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                                            Expanded(flex: 3, child: Text('SKU', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                                            Expanded(flex: 2, child: Text('STOCK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                                            Expanded(flex: 3, child: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                                            Expanded(flex: 4, child: Text('ACTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                                          ],
                                        ),
                                      ),
                                      ...variants.map((v) => _buildVariantRow(context, v, product)),
                                      const SizedBox(height: 12),
                                      // Add Variant Button
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton.icon(
                                          onPressed: () => _showAddVariantDialog(context, product),
                                          icon: const Icon(Icons.add, size: 18),
                                           label: const Text('Add Missing Quality Option / Size'),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.blue.shade700,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text('Error: $e', style: TextStyle(color: Colors.red.shade600)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    onPressed: () => ref.invalidate(inventoryListProvider),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(int stock, int threshold) {
    String status;
    Color bgColor;
    Color textColor;

    if (stock == -1) {
      status = 'In Stock';
      bgColor = Colors.green.shade100;
      textColor = Colors.green.shade800;
    } else if (stock <= 0) {
      status = 'Out of Stock';
      bgColor = Colors.red.shade100;
      textColor = Colors.red.shade800;
    } else if (stock <= threshold) {
      status = 'Low Stock';
      bgColor = Colors.orange.shade100;
      textColor = Colors.orange.shade800;
    } else {
      status = 'In Stock';
      bgColor = Colors.green.shade100;
      textColor = Colors.green.shade800;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _getProductStatusBadge(List<dynamic> variants) {
    if (variants.isEmpty) return const SizedBox();
    
    bool hasLow = false;
    bool hasOut = false;
    bool hasIn = false;
    
    for (final v in variants) {
      final stock = (v['current_stock'] as num?)?.toInt() ?? 0;
      final threshold = (v['low_stock_threshold'] as num?)?.toInt() ?? 5;
      
      if (stock <= 0 && stock != -1) {
        hasOut = true;
      } else if (stock <= threshold && stock != -1) {
        hasLow = true;
      } else {
        hasIn = true;
      }
    }
    
    String label = 'Mixed';
    Color color = Colors.orange;
    
    if (hasOut && !hasIn && !hasLow) {
      label = 'Out of Stock';
      color = Colors.red;
    } else if (hasIn && !hasOut && !hasLow) {
      label = 'In Stock';
      color = Colors.green;
    } else if (hasLow && !hasOut && !hasIn) {
      label = 'Low Stock';
      color = Colors.orange;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _buildVariantRow(BuildContext context, Map<String, dynamic> variant, Map<String, dynamic> product) {
    final stock = (variant['current_stock'] as num?)?.toInt() ?? 0;
    final threshold = (variant['low_stock_threshold'] as num?)?.toInt() ?? 5;
    final hasInventoryEntry = variant['has_inventory_entry'] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              variant['variation']?.toString().isNotEmpty == true ? variant['variation'].toString() : 'Standard',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              variant['sku']?.toString() ?? '-',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
          Expanded(
            flex: 2,
            child: stock == -1 
                ? const Text('Available', style: TextStyle(color: Colors.green, fontSize: 13, fontStyle: FontStyle.italic))
                : Text(stock.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          Expanded(
            flex: 3,
            child: _buildStatusBadge(stock, threshold),
          ),
          Expanded(
            flex: 4, // Slightly more room for action buttons
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showVariantStockDialog(context, product, variant),
                  icon: const Icon(Icons.edit, size: 14),
                  label: Text(variant['has_inventory_entry'] == true ? 'Set Stock' : 'Add to Inventory', style: const TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: variant['has_inventory_entry'] == true ? Colors.blue.shade50 : Colors.indigo.shade600,
                    foregroundColor: variant['has_inventory_entry'] == true ? Colors.blue.shade700 : Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                // Direct Out of Stock Button
                IconButton(
                  onPressed: () async {
                    try {
                      final service = ref.read(inventoryServiceProvider);
                      if (stock <= 0 && stock != -1) {
                        // Mark In Stock
                        await service.markInStock(
                          product['id'],
                          variant['variation'] ?? '',
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Marked as In Stock (50 units added)'))
                        );
                      } else {
                        // Mark Out of Stock
                        await service.markOutOfStock(
                          product['id'],
                          variant['variation'] ?? '',
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Marked as Out of Stock'))
                        );
                      }
                      ref.invalidate(inventoryListProvider);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
                      );
                    }
                  },
                  icon: Icon(
                    (stock <= 0 && stock != -1) ? Icons.check_circle_outline : Icons.block, 
                    color: (stock <= 0 && stock != -1) ? Colors.green : Colors.orange.shade700, 
                    size: 18
                  ),
                  tooltip: (stock <= 0 && stock != -1) ? 'Mark In Stock' : 'Direct Out of Stock',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                if (variant['has_inventory_entry'] == true) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _showDeleteConfirmation(context, product, variant),
                    icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
                    tooltip: 'Remove from Inventory',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Map<String, dynamic> product, Map<String, dynamic> variant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Inventory?'),
        content: Text('This will stop tracking stock levels for "${variant['variation'].toString().isNotEmpty ? variant['variation'] : 'Standard'}" of ${product['product_name']}. Existing stock data will be removed from the inventory table.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(inventoryServiceProvider).deleteInventoryVariation(
                  product['id'],
                  variant['variation'] ?? '',
                );
                ref.invalidate(inventoryListProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Item removed from inventory tracking'))
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
                );
              }
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showVariantStockDialog(BuildContext context, Map<String, dynamic> product, Map<String, dynamic> variant) {
    final quantityController = TextEditingController(text: variant['current_stock'] == -1 ? '0' : variant['current_stock'].toString());
    final isUntracked = variant['current_stock'] == -1;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.inventory_2, color: Colors.blue, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(product['product_name']?.toString() ?? 'Set Stock', 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(
                    'Variant: ${variant['variation']?.toString().isNotEmpty == true ? variant['variation'] : 'Standard'}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.normal),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter the current absolute stock level for this item.', 
              style: TextStyle(fontSize: 13, color: Colors.blueGrey)),
            const SizedBox(height: 20),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Total Quantity in Stock',
                prefixIcon: const Icon(Icons.numbers),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
                helperText: isUntracked ? 'Currently untracked. Setting a value will start tracking.' : 'Current: ${variant['current_stock']}',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final newStock = int.tryParse(quantityController.text) ?? 0;
              final currentStock = variant['current_stock'] == -1 ? 0 : ((variant['current_stock'] as num).toInt());
              final delta = newStock - currentStock;
              
              Navigator.pop(context);
              
              try {
                await ref.read(inventoryServiceProvider).adjustStock(
                  productId: product['id'],
                  qualityOption: variant['variation'] ?? '',
                  delta: delta == 0 ? 0 : delta,
                  reason: 'Inventory Correction',
                );
                ref.invalidate(inventoryListProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Stock level updated successfully'),
                    behavior: SnackBarBehavior.floating,
                  )
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
                );
              }
            },
            child: const Text('Update Stock'),
          ),
        ],
      ),
    );
  }

  void _showAddVariantDialog(BuildContext context, Map<String, dynamic> product) {
    final variantNameController = TextEditingController();
    final quantityController = TextEditingController(text: '0');
    
    // Get all predefined quality options that are NOT already in the inventory list
    final List<dynamic> predefinedOptions = (product['quality_options'] as List?) ?? [];
    final Set<String> currentVariants = (product['variants'] as List)
        .where((v) => v['has_inventory_entry'] == true)
        .map((v) => v['variation'].toString().toLowerCase())
        .toSet();
    
    final List<String> missingOptions = predefinedOptions.map((opt) {
      if (opt is Map) {
        return (opt['name'] ?? opt['quality_option'] ?? opt['option'] ?? '').toString().trim();
      }
      return opt.toString();
    }).where((name) => name.isNotEmpty && !currentVariants.contains(name.toLowerCase())).toList();

    String? selectedOption = missingOptions.isNotEmpty ? missingOptions.first : null;
    bool isOther = missingOptions.isEmpty;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_business, color: Colors.indigo, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Add Inventory Item', 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Product: ${product['product_name']}', 
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 20),
              
              const Text('Select Quality Option / Size', 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
              const SizedBox(height: 8),
              
              if (missingOptions.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  value: isOther ? 'other' : selectedOption,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.style_outlined),
                  ),
                  items: [
                    ...missingOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))),
                    const DropdownMenuItem(value: 'other', child: Text('Other (Type Manually)', 
                      style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
                  ],
                  onChanged: (v) {
                    setState(() {
                      if (v == 'other') {
                        isOther = true;
                      } else {
                        isOther = false;
                        selectedOption = v;
                      }
                    });
                  },
                ),
                if (isOther) const SizedBox(height: 12),
              ],
              
              if (isOther)
                TextField(
                  controller: variantNameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Variation Name',
                    hintText: 'e.g. 50 Ltr, 100 Kg',
                    prefixIcon: const Icon(Icons.label_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                
              const SizedBox(height: 16),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Opening Stock Level',
                  prefixIcon: const Icon(Icons.numbers),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final vName = isOther ? variantNameController.text.trim() : (selectedOption ?? '');
                if (vName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select or enter a name'))
                  );
                  return;
                }
                
                final initialStock = int.tryParse(quantityController.text) ?? 0;
                Navigator.pop(context);
                
                try {
                  await ref.read(inventoryServiceProvider).adjustStock(
                    productId: product['id'],
                    qualityOption: vName,
                    delta: initialStock,
                    reason: 'Initial inventory entry',
                  );
                  ref.invalidate(inventoryListProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added stock for "$vName" successfully'))
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
                  );
                }
              },
              child: const Text('Add to Inventory'),
            ),
          ],
        ),
      ),
    );
  }

  String _normalizeCategoryName(String cat) {
    String s = cat.trim().toLowerCase();
    if (s == 'waterproofing chemical' || s == 'waterproofing chemicals') return 'waterproofing chemicals';
    return s;
  }
}
