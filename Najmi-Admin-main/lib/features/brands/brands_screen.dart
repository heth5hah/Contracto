import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import 'brands_provider.dart';
import '../categories/category_model.dart';
import 'add_edit_brand_dialog.dart';
import 'brand_products_screen.dart';
import 'add_product_dialog.dart';

class BrandsScreen extends ConsumerStatefulWidget {
  const BrandsScreen({super.key});

  @override
  ConsumerState<BrandsScreen> createState() => _BrandsScreenState();
}

class _BrandsScreenState extends ConsumerState<BrandsScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Force a refresh when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(brandsNotifierProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final brandsAsync = ref.watch(brandsNotifierProvider);
    print('BrandsScreen: Building with state: ${brandsAsync.runtimeType}');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Brands Management'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search and Add Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search brands...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 140,
                  child: ElevatedButton.icon(
                    onPressed: () => _showAddBrandDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Brand', style: TextStyle(fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Brands List
          Expanded(
            child: brandsAsync.when(
              data: (brands) {
                print('BrandsScreen: Received ${brands.length} brands');
                final filteredBrands = _searchQuery.isEmpty
                    ? brands
                    : brands.where((brand) =>
                        brand.name.toLowerCase().contains(_searchQuery) ||
                        (brand.description?.toLowerCase().contains(_searchQuery) ?? false)).toList();

                print('BrandsScreen: Filtered to ${filteredBrands.length} brands');
                
                if (filteredBrands.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.branding_watermark_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? 'No Brands Found' : 'No brands match your search',
                          style: TextStyle(color: Colors.grey[500], fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isEmpty 
                              ? 'Click "Add Brand" to get started' 
                              : 'Try a different search term',
                          style: TextStyle(color: Colors.grey[400], fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredBrands.length,
                  itemBuilder: (context, index) {
                    final brand = filteredBrands[index];
                    return _buildBrandCard(context, brand);
                  },
                );
              },
              loading: () {
                print('BrandsScreen: Loading state');
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading brands...'),
                    ],
                  ),
                );
              },
              error: (err, stack) {
                print('BrandsScreen: Error loading brands: $err');
                print('BrandsScreen: Stack trace: $stack');
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        const Text(
                          'Error loading brands',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Error Details:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[900],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                err.toString(),
                                style: TextStyle(
                                  color: Colors.red[800],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            print('BrandsScreen: Retry button pressed');
                            ref.invalidate(brandsNotifierProvider);
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            // Show more details in a dialog
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Error Details'),
                                content: SingleChildScrollView(
                                  child: Text('$err\n\n$stack'),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: const Text('Show Full Error'),
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

  Widget _buildBrandCard(BuildContext context, Brand brand) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          radius: 30,
          backgroundColor: Colors.grey[200],
          child: brand.logo != null
              ? ClipOval(
                  child: Image.network(
                    brand.logo!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.branding_watermark, size: 30),
                  ),
                )
              : const Icon(Icons.branding_watermark, size: 30),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                brand.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: brand.isActive ? Colors.green[100] : Colors.red[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                brand.isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                  color: brand.isActive ? Colors.green[700] : Colors.red[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (brand.description != null && brand.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  brand.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BrandProductsScreen(
                          brandId: brand.id,
                          brandName: brand.name,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.inventory_2, size: 16),
                  label: const Text('View Products'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddProductDialog(context, brand),
                  icon: const Icon(Icons.add_shopping_cart, size: 16),
                  label: const Text('Add Product'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showBrandDiscountDialog(brand),
                  icon: const Icon(Icons.percent, size: 16),
                  label: const Text('Set Discount'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              child: const Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
              onTap: () => Future.delayed(
                const Duration(milliseconds: 100),
                () => _showEditBrandDialog(context, brand),
              ),
            ),
            PopupMenuItem(
              child: Row(
                children: [
                  Icon(
                    brand.isActive ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(brand.isActive ? 'Deactivate' : 'Activate'),
                ],
              ),
              onTap: () => Future.delayed(
                const Duration(milliseconds: 100),
                () => _toggleBrandStatus(context, brand),
              ),
            ),
            PopupMenuItem(
              child: const Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
              onTap: () => Future.delayed(
                const Duration(milliseconds: 100),
                () => _deleteBrand(context, brand),
              ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  void _showAddBrandDialog(BuildContext context) {
    print('BrandsScreen: Opening add brand dialog');
    try {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          print('BrandsScreen: Dialog builder called');
          return AddEditBrandDialog();
        },
      ).then((_) {
        print('BrandsScreen: Dialog closed');
      }).catchError((error) {
        print('BrandsScreen: Error showing dialog: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening dialog: $error')),
        );
      });
    } catch (e) {
      print('BrandsScreen: Exception showing dialog: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showEditBrandDialog(BuildContext context, Brand brand) {
    print('BrandsScreen: Opening edit brand dialog for: ${brand.name}');
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AddEditBrandDialog(brand: brand),
    ).then((_) {
      print('BrandsScreen: Edit dialog closed');
    });
  }

  void _showAddProductDialog(BuildContext context, Brand brand) {
    print('BrandsScreen: Opening add product dialog for brand: ${brand.name}');
    try {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          print('BrandsScreen: Add product dialog builder called');
          return AddProductDialog(brandId: brand.id);
        },
      ).then((_) {
        print('BrandsScreen: Add product dialog closed');
      }).catchError((error) {
        print('BrandsScreen: Error showing add product dialog: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening dialog: $error')),
        );
      });
    } catch (e) {
      print('BrandsScreen: Exception showing add product dialog: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _toggleBrandStatus(BuildContext context, Brand brand) {
    ref.read(brandsNotifierProvider.notifier).toggleBrandStatus(
      brand.id,
      !brand.isActive,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Brand ${brand.isActive ? 'deactivated' : 'activated'} successfully'),
      ),
    );
  }

  void _deleteBrand(BuildContext context, Brand brand) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Brand'),
        content: Text('Are you sure you want to delete "${brand.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(brandsNotifierProvider.notifier).deleteBrand(brand.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Brand deleted successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting brand: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showBrandDiscountDialog(Brand brand) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Apply Discount - ${brand.name}'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Discount Percentage',
              hintText: 'Enter discount (0 - 100)',
              suffixText: '%',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final text = controller.text.trim();
                final value = double.tryParse(text);
                if (value == null || value < 0 || value > 100) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid discount between 0 and 100'),
                    ),
                  );
                  return;
                }

                Navigator.of(context).pop();
                await _applyDiscountToBrand(brand, value);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _applyDiscountToBrand(Brand brand, double discountPercent) async {
    try {
      final supabase = ref.read(supabaseProvider);

      // Get products where this brand is primary or in brand_ids array
      final response = await supabase
          .from('products')
          .select('id, mrp')
          .or('brand_id.eq.${brand.id},brand_ids.cs.["${brand.id}"]');

      final products = (response as List).cast<Map<String, dynamic>>();

      for (final product in products) {
        final mrpValue = (product['mrp'] as num?)?.toDouble();
        double? finalPrice;
        if (mrpValue != null) {
          finalPrice = double.parse(
            (mrpValue * (1 - discountPercent / 100)).toStringAsFixed(2),
          );
        }

        final updateData = <String, dynamic>{
          'discount_percent': discountPercent,
        };

        if (finalPrice != null) {
          updateData['final_price'] = finalPrice;
        }

        await supabase
            .from('products')
            .update(updateData)
            .eq('id', product['id']);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            products.isEmpty
                ? 'No products found for ${brand.name} to apply discount.'
                : 'Applied $discountPercent% discount to ${products.length} products for ${brand.name}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error applying discount: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
