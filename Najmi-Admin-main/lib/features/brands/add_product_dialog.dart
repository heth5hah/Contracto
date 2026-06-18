import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import '../categories/categories_provider.dart';
import '../categories/category_model.dart';

class AddProductDialog extends ConsumerStatefulWidget {
  final String brandId;
  final Map<String, dynamic>? product;

  const AddProductDialog({super.key, required this.brandId, this.product});

  @override
  ConsumerState<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends ConsumerState<AddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _mrpController = TextEditingController();
  final _finalPriceController = TextEditingController();
  final _discountPercentController = TextEditingController();
  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _populateFields();
  }

  void _populateFields() {
    if (widget.product != null) {
      _nameController.text = widget.product!['product_name'] ?? '';
      _categoryController.text = widget.product!['category'] ?? '';
      _descriptionController.text = widget.product!['description'] ?? '';
      _mrpController.text = widget.product!['mrp']?.toString() ?? '';
      _finalPriceController.text =
          widget.product!['final_price']?.toString() ?? '';
      _discountPercentController.text =
          widget.product!['discount_percent']?.toString() ?? '';
      _isActive = widget.product!['is_active'] ?? true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _mrpController.dispose();
    _finalPriceController.dispose();
    _discountPercentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return AlertDialog(
      title: Text(widget.product == null ? 'Add Product' : 'Edit Product'),
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
                categoriesAsync.when(
                  data: (categories) {
                    // Filter duplicates and prepare names
                    final categoryNames = categories.map((c) => c.name).toSet().toList();
                    categoryNames.sort();

                    // Safety check: ensure current category is in list, if not add it
                    String? selectedCategory;
                    if (_categoryController.text.isNotEmpty) {
                      try {
                        selectedCategory = categoryNames.firstWhere(
                          (name) => name.toLowerCase().trim() == _categoryController.text.toLowerCase().trim(),
                        );
                      } catch (_) {
                        selectedCategory = _categoryController.text.trim();
                        categoryNames.add(selectedCategory);
                      }
                    }

                    return DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      hint: const Text('Select category...'),
                      items: categoryNames.map((name) => DropdownMenuItem(
                        value: name,
                        child: Text(name),
                      )).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _categoryController.text = value;
                          });
                        }
                      },
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, _) => TextFormField(
                    controller: _categoryController,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: const OutlineInputBorder(),
                      helperText: 'Failed to load categories: $e',
                    ),
                  ),
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
                      // Wide screen: show in a row
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
                      // Narrow screen: show in a column
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
              : Text(widget.product == null ? 'Add Product' : 'Save Changes'),
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
        'brand_id': widget.brandId,
        'category': _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'mrp': _mrpController.text.trim().isEmpty
            ? null
            : double.tryParse(_mrpController.text.trim()),
        'final_price': _finalPriceController.text.trim().isEmpty
            ? null
            : double.tryParse(_finalPriceController.text.trim()),
        'discount_percent': _discountPercentController.text.trim().isEmpty
            ? null
            : double.tryParse(_discountPercentController.text.trim()),
        'is_active': _isActive,
        'photos': <String>[],
      };

      if (widget.product == null) {
        print('AddProductDialog: Inserting product with data: $productData');
        await supabase.from('products').insert(productData);
      } else {
        // Update existing product
        print('AddProductDialog: Updating product with data: $productData');
        await supabase
            .from('products')
            .update(productData)
            .eq('id', widget.product!['id']);
      }
      print(
        'AddProductDialog: Product ${widget.product == null ? "inserted" : "updated"} successfully',
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.product == null
                  ? 'Product added successfully'
                  : 'Product updated successfully',
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      print(
        'AddProductDialog: Error ${widget.product == null ? "adding" : "updating"} product: $e',
      );
      print('AddProductDialog: Stack trace: $stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error ${widget.product == null ? "adding" : "updating"} product: ${e.toString()}',
            ),
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
