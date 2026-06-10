import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import '../brands/add_product_dialog.dart';

class CategoryProductsScreen extends ConsumerStatefulWidget {
  final String categoryName;
  final String categoryId;

  const CategoryProductsScreen({
    super.key,
    required this.categoryName,
    required this.categoryId,
  });

  @override
  ConsumerState<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends ConsumerState<CategoryProductsScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final supabase = ref.read(supabaseProvider);
      
      // Get products where category matches the category name
      final response = await supabase
          .from('products')
          .select('*')
          .eq('category', widget.categoryName)
          .order('product_name');

      setState(() {
        _products = (response as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Products - ${widget.categoryName}'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Apply discount to all products in this category',
            icon: const Icon(Icons.percent),
            onPressed: (_loading || _products.isEmpty)
                ? null
                : () => _showApplyDiscountDialog(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error loading products', style: TextStyle(color: Colors.grey[700])),
                      const SizedBox(height: 8),
                      Text(_error!, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadProducts,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _products.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            'No products found',
                            style: TextStyle(color: Colors.grey[500], fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No products found in this category',
                            style: TextStyle(color: Colors.grey[400], fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadProducts,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _products.length,
                        itemBuilder: (context, index) {
                          final product = _products[index];
                          return _buildProductCard(product);
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddProductDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: (product['photos'] as List?)?.isNotEmpty == true
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  (product['photos'] as List).first,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 40),
                ),
              )
            : const Icon(Icons.image, size: 40),
        title: Text(
          product['product_name'] ?? 'Unnamed Product',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product['brand_id'] != null)
              FutureBuilder(
                future: _getBrandName(product['brand_id']),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Text('Brand: ${snapshot.data}');
                  }
                  return const SizedBox.shrink();
                },
              ),
            if (product['mrp'] != null)
              Text('MRP: ₹${product['mrp']}'),
            if (product['final_price'] != null)
              Text('Price: ₹${product['final_price']}'),
            if (product['discount_percent'] != null)
              Text('Discount: ${product['discount_percent']}%'),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (product['is_active'] ?? true) ? Colors.green[100] : Colors.red[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    (product['is_active'] ?? true) ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: (product['is_active'] ?? true) ? Colors.green[700] : Colors.red[700],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Future<String?> _getBrandName(String? brandId) async {
    if (brandId == null) return null;
    try {
      final supabase = ref.read(supabaseProvider);
      final response = await supabase
          .from('brands')
          .select('name')
          .eq('id', brandId)
          .single();
      return response['name'] as String?;
    } catch (e) {
      return null;
    }
  }

  void _showApplyDiscountDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Apply Discount - ${widget.categoryName}'),
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
                await _applyDiscountToAllProducts(value);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _applyDiscountToAllProducts(double discountPercent) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final supabase = ref.read(supabaseProvider);

      for (final product in _products) {
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

      await _loadProducts();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Applied $discountPercent% discount to ${_products.length} products in ${widget.categoryName}',
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error applying discount: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAddProductDialog(BuildContext context) {
    // For adding product to category, we need to pass category name instead of brandId
    // Let's create a modified version or use a different approach
    showDialog(
      context: context,
      builder: (context) => AddProductToCategoryDialog(
        categoryName: widget.categoryName,
      ),
    ).then((_) => _loadProducts());
  }
}

// Dialog for adding product to category
class AddProductToCategoryDialog extends ConsumerStatefulWidget {
  final String categoryName;

  const AddProductToCategoryDialog({super.key, required this.categoryName});

  @override
  ConsumerState<AddProductToCategoryDialog> createState() => _AddProductToCategoryDialogState();
}

class _AddProductToCategoryDialogState extends ConsumerState<AddProductToCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _mrpController = TextEditingController();
  final _finalPriceController = TextEditingController();
  final _discountPercentController = TextEditingController();
  String? _selectedBrandId;
  List<Map<String, dynamic>> _brands = [];
  bool _isActive = true;
  bool _saving = false;
  bool _loadingBrands = true;

  @override
  void initState() {
    super.initState();
    _loadBrands();
  }

  Future<void> _loadBrands() async {
    try {
      final supabase = ref.read(supabaseProvider);
      final response = await supabase
          .from('brands')
          .select('id, name')
          .eq('is_active', true)
          .order('name');
      
      setState(() {
        _brands = (response as List).cast<Map<String, dynamic>>();
        _loadingBrands = false;
      });
    } catch (e) {
      setState(() {
        _loadingBrands = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _mrpController.dispose();
    _finalPriceController.dispose();
    _discountPercentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Product'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Product Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter product name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                if (_loadingBrands)
                  const Center(child: CircularProgressIndicator())
                else
                  DropdownButtonFormField<String>(
                    value: _selectedBrandId,
                    decoration: const InputDecoration(
                      labelText: 'Brand (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('No Brand'),
                      ),
                      ..._brands.map((brand) => DropdownMenuItem<String>(
                            value: brand['id'] as String,
                            child: Text(brand['name'] as String),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedBrandId = value;
                      });
                    },
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 600) {
                      return Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _mrpController,
                              decoration: const InputDecoration(
                                labelText: 'MRP (₹)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _finalPriceController,
                              decoration: const InputDecoration(
                                labelText: 'Final Price (₹)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _discountPercentController,
                              decoration: const InputDecoration(
                                labelText: 'Discount %',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          TextFormField(
                            controller: _mrpController,
                            decoration: const InputDecoration(
                              labelText: 'MRP (₹)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _finalPriceController,
                            decoration: const InputDecoration(
                              labelText: 'Final Price (₹)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _discountPercentController,
                            decoration: const InputDecoration(
                              labelText: 'Discount %',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Active'),
                  subtitle: const Text('Product will be visible to users'),
                  value: _isActive,
                  onChanged: (value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _saveProduct,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add Product'),
        ),
      ],
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final supabase = ref.read(supabaseProvider);

      final productData = <String, dynamic>{
        'product_name': _nameController.text.trim(),
        'category': widget.categoryName,
        'is_active': _isActive,
        'photos': <String>[],
      };

      if (_selectedBrandId != null) {
        productData['brand_id'] = _selectedBrandId;
      }

      if (_descriptionController.text.trim().isNotEmpty) {
        productData['description'] = _descriptionController.text.trim();
      }

      if (_mrpController.text.trim().isNotEmpty) {
        productData['mrp'] = double.tryParse(_mrpController.text.trim());
      }

      if (_finalPriceController.text.trim().isNotEmpty) {
        productData['final_price'] = double.tryParse(_finalPriceController.text.trim());
      }

      if (_discountPercentController.text.trim().isNotEmpty) {
        productData['discount_percent'] = double.tryParse(_discountPercentController.text.trim());
      }

      print('AddProductToCategoryDialog: Inserting product with data: $productData');
      await supabase.from('products').insert(productData);
      print('AddProductToCategoryDialog: Product inserted successfully');

      if (!mounted) return;
      Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added successfully')),
        );
      }
    } catch (e, stackTrace) {
      print('AddProductToCategoryDialog: Error adding product: $e');
      print('AddProductToCategoryDialog: Stack trace: $stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding product: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }
}

