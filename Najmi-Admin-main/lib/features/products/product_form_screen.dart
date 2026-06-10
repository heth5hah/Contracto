import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'product_model.dart';
import 'products_provider.dart';
import '../../main.dart';
import '../categories/categories_provider.dart';
import '../categories/category_model.dart';
import '../brands/brands_provider.dart';
import '../settings/unit_provider.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final Product? product;
  final String? initialCategory;
  final String? productId;

  const ProductFormScreen({
    super.key, 
    this.product, 
    this.initialCategory,
    this.productId,
  });

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  
  late TextEditingController _nameController;
  late TextEditingController _productIdController;
  late TextEditingController _descriptionController;
  late TextEditingController _hsnController;
  late TextEditingController _priceController;
  late TextEditingController _mrpController;
  late TextEditingController _subcategoryController;
  late TextEditingController _stockQuantityController;
  
  String? _selectedCategory;
  String? _selectedStockStatus;
  String? _selectedPricingType;
  double? _selectedGstPercent;
  
  List<String> _selectedBrandIds = [];
  List<QualityOption> _qualityOptions = [];
  List<XFile> _imageFiles = [];
  List<String> _existingPhotoUrls = []; // Tracks existing photos (can delete/reorder)
  bool _isLoading = false;
  String? _initError;
  Product? _loadedProduct;

  bool _isReturnable = true;

  final List<String> _pricingTypes = ['fixed_price', 'custom_pricing', 'quote_request'];
  final List<double> _gstRates = [0, 5, 12, 18, 28];

  // Unit Management
  List<String> _enabledUnitIds = []; // UUIDs from product_units
  String? _defaultUnitId; // UUID of selected default unit

  @override
  void initState() {
    print('DEBUG: ProductFormScreen.initState() started');
    super.initState();
    try {
      if (widget.product == null && widget.productId != null) {
        _loadProductById();
      } else {
        _initializeControllers();
        // Load assigned units if editing
        if (widget.product != null) {
          _loadAssignedUnits();
        }
      }
      print('DEBUG: ProductFormScreen.initState() completed successfully');
    } catch (e, stack) {
      print('CRITICAL ERROR in ProductFormScreen.initState: $e\n$stack');
      setState(() {
        _initError = e.toString();
      });
    }
  }

  Future<void> _loadProductById() async {
    try {
      setState(() => _isLoading = true);
      final supabase = Supabase.instance.client;
      
      // Use LEFT JOIN (no !inner) so products without brands are still returned
      final response = await supabase
          .from('products')
          .select('*, brands(*)')
          .eq('id', widget.productId!);
      
      if (response.isEmpty) {
        throw Exception('Product not found');
      }
      
      final data = response.first;
      _loadedProduct = Product.fromJson(data);
      _initializeControllers();
      await _loadAssignedUnits();
      setState(() => _isLoading = false);
    } catch (e, stack) {
      print('ERROR loading product: $e\n$stack');
      setState(() {
        _initError = 'Failed to load product: $e';
        _isLoading = false;
      });
    }
  }

  void _initializeControllers() {
    final p = _loadedProduct ?? widget.product;
    _nameController = TextEditingController(text: p?.productName);
    _productIdController = TextEditingController(text: p?.productId);
    _descriptionController = TextEditingController(text: p?.description);
    _priceController = TextEditingController(text: p?.finalPrice?.toString());
    _mrpController = TextEditingController(text: p?.mrp?.toString());
    _subcategoryController = TextEditingController(text: p?.subcategory);
    _stockQuantityController = TextEditingController(text: p?.stockQuantity?.toString() ?? '0');
    _hsnController = TextEditingController(text: p?.hsnNumber);
    
    _selectedCategory = p?.category ?? widget.initialCategory;
    _selectedStockStatus = p?.stockStatus ?? 'in_stock';
    _selectedPricingType = p?.pricingType ?? 'fixed_price';
    _selectedGstPercent = p?.gstPercent;
    
    _selectedBrandIds = p?.brandIds?.map((e) => e.toString()).toList() ?? [];
    _qualityOptions = List.from(p?.qualityOptions ?? []);
    _isReturnable = p?.isReturnable ?? true;
    _existingPhotoUrls = List<String>.from(p?.photos ?? []);
    
    // We treat the legacy p.unit as a potential default unit code, 
    // but the real mapping will happen in _loadAssignedUnits or via provider data.
    
    if (_qualityOptions.isEmpty && _selectedPricingType == 'fixed_price' && p?.finalPrice != null) {
      _qualityOptions.add(QualityOption(
        name: '${p?.unit ?? "Default"}',
        mrp: p?.mrp ?? 0.0,
        discount: 0.0,
        finalPrice: p?.finalPrice ?? 0.0,
      ));
    }
  }


  Future<void> _loadAssignedUnits() async {
    try {
      final product = _loadedProduct ?? widget.product;
      if (product == null) return;
      
      final supabase = Supabase.instance.client;
      // 1. Fetch assigned units for this product
      final response = await supabase
          .from('product_units')
          .select('unit_id, is_default')
          .eq('product_id', product.id);

      final List<String> loadedUnitIds = [];
      String? defaultId;

      for (var row in response) {
        final unitId = row['unit_id'] as String;
        final isDefault = row['is_default'] as bool;
        loadedUnitIds.add(unitId);
        if (isDefault) {
          defaultId = unitId;
        }
      }
      
      if (mounted) {
        setState(() {
          _enabledUnitIds = loadedUnitIds;
          _defaultUnitId = defaultId;
        });
      }
    } catch (e) {
      print('Error loading product units: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _productIdController.dispose();
    _descriptionController.dispose();
    _hsnController.dispose();
    _priceController.dispose();
    _mrpController.dispose();
    _subcategoryController.dispose();
    _stockQuantityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _imageFiles.add(pickedFile));
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final supabase = ref.read(supabaseProvider);
      List<String> photoUrls = List<String>.from(_existingPhotoUrls);
      
      for (var file in _imageFiles) {
        final bytes = await file.readAsBytes();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        final path = 'products/$fileName';
        
        final fileExt = file.name.split('.').last;
        await supabase.storage.from('product-photos').uploadBinary(
          path, 
          bytes, 
          fileOptions: FileOptions(contentType: 'image/$fileExt', upsert: true)
        );
        
        final imageUrl = supabase.storage.from('product-photos').getPublicUrl(path);
        photoUrls.add(imageUrl);
      }

      // Resolve Unit Code from Default Unit ID if available
      String? unitCode; 
      // If we have a selected default unit ID, allow it to override the legacy unit code if needed,
      // OR ensure that the unit code matches the default unit.
      if (_defaultUnitId != null) {
        final units = ref.read(activeUnitsProvider);
        if (units.isNotEmpty) {
           final unitObj = units.firstWhere((u) => u.id == _defaultUnitId, orElse: () => units.first);
           unitCode = unitObj.code;
        }
      }

      final product = Product(
        id: (_loadedProduct ?? widget.product)?.id ?? '',
        productName: _nameController.text.trim(),
        productId: _productIdController.text.trim(),
        description: _descriptionController.text.trim(),
        hsnNumber: _hsnController.text.trim(),
        category: _selectedCategory,
        subcategory: _subcategoryController.text.trim(),
        unit: unitCode,
        stockStatus: _selectedStockStatus ?? 'in_stock',
        stockQuantity: (int.tryParse(_stockQuantityController.text.trim()) ?? 0) == 0 ? null : int.tryParse(_stockQuantityController.text.trim()),
        pricingType: _selectedPricingType ?? 'fixed_price',
        gstPercent: _selectedGstPercent,
        finalPrice: double.tryParse(_priceController.text) ?? (_qualityOptions.isNotEmpty ? _qualityOptions.first.finalPrice : 0.0),
        mrp: double.tryParse(_mrpController.text) ?? (_qualityOptions.isNotEmpty ? _qualityOptions.first.mrp : 0.0),
        photos: photoUrls,
        brandIds: _selectedBrandIds,
        qualityOptions: _qualityOptions,
        isReturnable: _isReturnable,
      );

      String? savedProductId;
      final isEditing = (_loadedProduct ?? widget.product) != null;

      if (!isEditing) {
        final newProduct = await ref.read(productsProvider.notifier).addProduct(product, null);
        savedProductId = newProduct?.id;
      } else {
        await ref.read(productsProvider.notifier).updateProduct(product, null);
        savedProductId = (_loadedProduct ?? widget.product)!.id;
      }

      // Save Assigned Units
      if (savedProductId != null) {
        // Delete existing
        await supabase.from('product_units').delete().eq('product_id', savedProductId);
        
        // Prepare list, ensuring default unit is included if not already
        final Set<String> unitsToSave = Set.from(_enabledUnitIds);
        if (_defaultUnitId != null) {
          unitsToSave.add(_defaultUnitId!);
        }

        if (unitsToSave.isNotEmpty) {
           final List<Map<String, dynamic>> unitsInsert = unitsToSave.map((uid) => {
             'product_id': savedProductId,
             'unit_id': uid,
             'is_default': uid == _defaultUnitId
           }).toList();
           
           await supabase.from('product_units').insert(unitsInsert);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product saved successfully!')));
        context.pop();
        ref.refresh(productsProvider);
      }
    } catch (e) {
      print('DEBUG: Error in _saveProduct: $e');
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.contains('column') && errorMsg.contains('does not exist')) {
          errorMsg = 'Database Link Error: Some new fields might be missing in your Supabase products table.';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(errorMsg), 
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 10),
          action: SnackBarAction(label: 'Dismiss', textColor: Colors.white, onPressed: () {}),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Initialization Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                const Text('Failed to initialize form.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                Text(_initError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: () => context.pop(), child: const Text('Go Back')),
              ],
            ),
          ),
        ),
      );
    }
    try {
      print('DEBUG: ProductFormScreen.build() started');
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(widget.product == null ? 'Add Product' : 'Edit Product'),
          actions: [
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.only(right: 16), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
            else
              TextButton(
                onPressed: _saveProduct,
                child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection(
                  title: 'Basic Information',
                  child: _buildBasicInfo(),
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: 'Category Information',
                  child: _buildCategoryInfo(),
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: 'Unit Configuration',
                  child: _buildUnitConfig(),
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: 'Pricing Configuration',
                  child: _buildPricingConfig(),
                ),
                const SizedBox(height: 24),
                if (_selectedPricingType != 'quote_request')
                  _buildSection(
                    title: 'Product Details',
                    subtitle: 'Quality Options with Pricing (Optional)',
                    child: _buildQualityOptions(),
                  ),
                if (_selectedPricingType != 'quote_request')
                  const SizedBox(height: 24),
                _buildSection(
                  title: 'Product Photos',
                  child: _buildPhotoSection(),
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: 'Additional Information',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 4,
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Enter product description',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Return Available'),
                        subtitle: const Text('Allow customers to return this product after delivery'),
                        value: _isReturnable,
                        onChanged: (bool value) {
                          setState(() {
                            _isReturnable = value;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                        activeColor: const Color(0xFF3B82F6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: 'Tax Information',
                  child: _buildTaxInfo(),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                     OutlinedButton(
                      onPressed: () => context.pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        minimumSize: const Size(120, 50),
                        side: const BorderSide(color: Color(0xFF64748B)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveProduct,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(widget.product == null ? 'Save Product' : 'Update Product'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(160, 50),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      );
    } catch (e, stack) {
      print('CRITICAL ERROR in ProductFormScreen.build: $e\n$stack');
      return Scaffold(
        appBar: AppBar(title: const Text('Error Rendering Form')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                const Text('Something went wrong while loading the form.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                Text(e.toString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: () => context.pop(), child: const Text('Go Back')),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildSection({required String title, String? subtitle, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 20, color: const Color(0xFF3B82F6)),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))),
          ],
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildBasicInfo() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildTextField(
                controller: _productIdController,
                label: 'Product ID',
                hint: 'Enter unique product ID',
                required: true,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildTextField(
                controller: _nameController,
                label: 'Product Name',
                hint: 'Enter product name',
                required: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildDropdownField<String>(
                label: 'Stock Status',
                value: _selectedStockStatus,
                items: const [
                  DropdownMenuItem(value: 'in_stock', child: Text('In Stock')),
                  DropdownMenuItem(value: 'out_of_stock', child: Text('Out of Stock')),
                ],
                onChanged: (v) => setState(() => _selectedStockStatus = v),
                required: true,
              ),
            ),
            if (_selectedStockStatus == 'in_stock') ...[
              const SizedBox(width: 24),
              Expanded(
                child: _buildTextField(
                  controller: _stockQuantityController,
                  label: 'Stock Quantity',
                  hint: 'Enter quantity',
                  isNumber: true,
                ),
              ),
            ] else 
               const Spacer(),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryInfo() {
    final categoriesAsync = ref.watch(categoriesProvider);
    final brandsAsync = ref.watch(brandsNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Brands (Optional - Multiple Selection)', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Color(0xFF334155))),
                  const SizedBox(height: 8),
                  brandsAsync.when(
                    data: (brands) => _buildBrandsMultiSelect(brands),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                children: [
                  categoriesAsync.when(
                    data: (categories) {
                      print('DEBUG: Categories loaded: ${categories.length}');
                      
                      // Filter duplicates and prepare names
                      final uniqueCategories = <String, Category>{};
                      for (var c in categories) {
                        uniqueCategories[c.name] = c;
                      }
                      
                      final categoryNames = uniqueCategories.keys.toList();
                      
                      // SAFETY CHECK: Ensure _selectedCategory is valid in the dropdown
                      String? dropdownValue = _selectedCategory;
                      if (dropdownValue != null) {
                        bool exists = categoryNames.any((name) => name == dropdownValue);
                        if (!exists) {
                           // Try case-insensitive match
                           try {
                             dropdownValue = categoryNames.firstWhere(
                               (name) => name.toLowerCase().trim() == _selectedCategory!.toLowerCase().trim()
                             );
                             // Update the state so future saves use the correct case
                             WidgetsBinding.instance.addPostFrameCallback((_) {
                               if (mounted) setState(() => _selectedCategory = dropdownValue);
                             });
                           } catch (_) {
                             // Not found at all, set to null to avoid crash
                             dropdownValue = null;
                           }
                        }
                      }

                      return _buildDropdownField<String>(
                        label: 'Category',
                        value: dropdownValue,
                        items: categoryNames.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                        onChanged: (v) => setState(() => _selectedCategory = v),
                        required: true,
                        hint: 'Select or type category...',
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                  ),
                  const SizedBox(height: 20),
                   _buildTextField(
                    controller: _subcategoryController, 
                    label: 'Subcategory',
                    hint: 'Search or type subcategory...',
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBrandsMultiSelect(List<Brand> allBrands) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      constraints: const BoxConstraints(minHeight: 120, maxHeight: 180),
      child: ListView.builder(
        padding: const EdgeInsets.all(4),
        itemCount: allBrands.length,
        itemBuilder: (context, index) {
          final brand = allBrands[index];
          final isSelected = _selectedBrandIds.contains(brand.id);
          return CheckboxListTile(
            title: Text(brand.name, style: const TextStyle(fontSize: 13)),
            value: isSelected,
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  _selectedBrandIds.add(brand.id);
                } else {
                  _selectedBrandIds.remove(brand.id);
                }
              });
            },
            dense: true,
            visualDensity: VisualDensity.compact,
            controlAffinity: ListTileControlAffinity.leading,
          );
        },
      ),
    );
  }

  Widget _buildUnitConfig() {
    final unitState = ref.watch(unitProvider);
    final units = ref.watch(activeUnitsProvider);

    if (unitState.isLoading && units.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()));
    }
    
    if (unitState.error != null && units.isEmpty) {
      return Text('Error loading units: ${unitState.error}', style: const TextStyle(color: Colors.red));
    }

    if (units.isEmpty) {
      return const Text('No units configured. Please add units in Settings.');
    }
    
    final enabledUnitsList = units.where((u) => _enabledUnitIds.contains(u.id)).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Enabled Units (Select all that apply)', style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155)
        )),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(8),
          ),
          constraints: const BoxConstraints(maxHeight: 200),
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: units.length,
            itemBuilder: (context, index) {
              final unit = units[index];
              final isEnabled = _enabledUnitIds.contains(unit.id);
              return CheckboxListTile(
                title: Text('${unit.name} (${unit.code})', style: const TextStyle(fontSize: 14)),
                value: isEnabled,
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (val) {
                  setState(() {
                      if (val == true) {
                        _enabledUnitIds.add(unit.id);
                        if (_enabledUnitIds.length == 1) {
                          _defaultUnitId = unit.id;
                        }
                      } else {
                        _enabledUnitIds.remove(unit.id);
                        if (_defaultUnitId == unit.id) {
                          _defaultUnitId = _enabledUnitIds.isNotEmpty ? _enabledUnitIds.first : null;
                        }
                      }
                  });
                },
              );
            },
          ),
        ),
        
        const SizedBox(height: 24),
        
          _buildDropdownField<String>(
            label: 'Default Display Unit',
            value: _defaultUnitId,
            items: enabledUnitsList.map((u) => DropdownMenuItem(
              value: u.id,
              child: Text('${u.name} (${u.code})'),
            )).toList(),
            onChanged: (val) => setState(() => _defaultUnitId = val),
            hint: enabledUnitsList.isEmpty ? 'Enable units first' : 'Select Default Unit',
            required: true,
          ),
          if (enabledUnitsList.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('At least one unit must be enabled', style: TextStyle(color: Colors.orange, fontSize: 12)),
            ),
      ],
    );
  }

  Widget _buildPricingConfig() {
    return _buildDropdownField<String>(
      label: 'Pricing Type',
      value: _selectedPricingType,
      items: _pricingTypes.map((t) => DropdownMenuItem(
        value: t, 
        child: Text(t.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' '))
      )).toList(),
      onChanged: (v) => setState(() => _selectedPricingType = v),
      required: true,
    );
  }

  Widget _buildQualityOptions() {
    return Column(
      children: [
        Table(
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(1),
            3: FlexColumnWidth(1),
            4: FixedColumnWidth(50),
          },
          border: TableBorder.all(color: const Color(0xFFF1F5F9), width: 1),
          children: [
            const TableRow(
              decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
              children: [
                Padding(padding: EdgeInsets.all(12), child: Text('Quality Option', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B)))),
                Padding(padding: EdgeInsets.all(12), child: Text('MRP (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B)))),
                Padding(padding: EdgeInsets.all(12), child: Text('Discount (%)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B)))),
                Padding(padding: EdgeInsets.all(12), child: Text('Final Price (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B)))),
                SizedBox(),
              ],
            ),
            ..._qualityOptions.asMap().entries.map((entry) {
              final idx = entry.key;
              final opt = entry.value;
              return TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextFormField(
                      initialValue: opt.name,
                      style: const TextStyle(fontSize: 13),
                      onChanged: (v) => _updateQualityOption(idx, name: v),
                      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextFormField(
                      initialValue: opt.mrp == 0 ? '' : opt.mrp.toString(),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 13),
                      onChanged: (v) => _updateQualityOption(idx, mrp: double.tryParse(v) ?? 0.0),
                      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), hintText: '0.00'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextFormField(
                      initialValue: opt.discount == 0 ? '' : opt.discount.toString(),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 13),
                      onChanged: (v) => _updateQualityOption(idx, discount: double.tryParse(v) ?? 0.0),
                      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), hintText: '0'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextFormField(
                      key: ValueKey('final_price_${idx}_${opt.finalPrice}'),
                      initialValue: opt.finalPrice == 0 ? '' : opt.finalPrice.toStringAsFixed(2),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      onChanged: (v) => _updateQualityOption(idx, finalPrice: double.tryParse(v) ?? 0.0),
                      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), hintText: '0.00'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFEF4444), size: 20),
                    onPressed: () => setState(() => _qualityOptions.removeAt(idx)),
                  ),
                ],
              );
            }).toList(),
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            onPressed: () => setState(() => _qualityOptions.add(QualityOption(name: '', mrp: 0.0, discount: 0.0, finalPrice: 0.0))),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Quality Option'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  void _updateQualityOption(int index, {String? name, double? mrp, double? discount, double? finalPrice}) {
    final opt = _qualityOptions[index];
    double newMrp = mrp ?? opt.mrp;
    double newDiscount = discount ?? opt.discount;
    double newFinalPrice = finalPrice ?? opt.finalPrice;

    if (mrp != null || discount != null) {
      newFinalPrice = newMrp * (1 - newDiscount / 100);
    }

    setState(() {
      _qualityOptions[index] = QualityOption(
        name: name ?? opt.name,
        mrp: newMrp,
        discount: newDiscount,
        finalPrice: newFinalPrice,
      );
    });
  }

  void _removeExistingPhoto(int index) async {
    final url = _existingPhotoUrls[index];
    setState(() => _existingPhotoUrls.removeAt(index));
    
    // Try to delete from Supabase storage (best effort)
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      // Extract storage path after 'product-photos/'
      final bucketIndex = pathSegments.indexOf('product-photos');
      if (bucketIndex != -1 && bucketIndex + 1 < pathSegments.length) {
        final storagePath = pathSegments.sublist(bucketIndex + 1).join('/');
        await Supabase.instance.client.storage.from('product-photos').remove([storagePath]);
      }
    } catch (e) {
      print('Could not delete from storage: $e');
    }
  }

  void _reorderExistingPhoto(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final url = _existingPhotoUrls.removeAt(oldIndex);
      _existingPhotoUrls.insert(newIndex, url);
    });
  }

  Widget _buildPhotoSection() {
    final allEmpty = _imageFiles.isEmpty && _existingPhotoUrls.isEmpty;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Upload photos. Existing photos can be deleted or reordered.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontStyle: FontStyle.italic)),
        const SizedBox(height: 16),
        // Upload area
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFFFBFDFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.5), style: BorderStyle.solid),
          ),
          child: Column(
            children: [
              const Icon(Icons.cloud_upload_outlined, size: 48, color: Color(0xFF64748B)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Drag & drop photos here or ', style: TextStyle(fontSize: 14, color: Color(0xFF1E293B))),
                  GestureDetector(
                    onTap: _pickImage,
                    child: const Text('click to browse', style: TextStyle(fontSize: 14, color: Color(0xFF3B82F6), fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('PNG, JPEG files up to 20MB each', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ],
          ),
        ),

        // Existing photos (reorderable + deletable)
        if (_existingPhotoUrls.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.photo_library_outlined, size: 18, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text('Uploaded Photos (${_existingPhotoUrls.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const Spacer(),
              const Text('Drag to reorder • First photo is the cover', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ],
          ),
          const SizedBox(height: 12),
          _buildReorderablePhotoGrid(),
        ],

        // New photos pending upload
        if (_imageFiles.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.add_photo_alternate_outlined, size: 18, color: Color(0xFF10B981)),
              const SizedBox(width: 8),
              Text('New Photos (${_imageFiles.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _imageFiles.asMap().entries.map((entry) {
              final idx = entry.key;
              final file = entry.value;
              return _buildImageThumb(file.path, () => setState(() => _imageFiles.removeAt(idx)), isLocal: true);
            }).toList(),
          ),
        ],

        if (allEmpty) ...[
          const SizedBox(height: 16),
          const Center(child: Text('No photos added yet', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13))),
        ],
      ],
    );
  }

  Widget _buildReorderablePhotoGrid() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: _existingPhotoUrls.length,
      onReorder: _reorderExistingPhoto,
      proxyDecorator: (child, index, animation) {
        return Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final url = _existingPhotoUrls[index];
        final isFirst = index == 0;
        return Container(
          key: ValueKey(url),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isFirst ? const Color(0xFFF0F9FF) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isFirst ? const Color(0xFF3B82F6).withOpacity(0.4) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              // Drag handle
              ReorderableDragStartListener(
                index: index,
                child: const MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.drag_indicator, color: Color(0xFF94A3B8), size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Position badge
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: isFirst ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              // Image thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  url, width: 80, height: 60, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 80, height: 60,
                    color: const Color(0xFFF1F5F9),
                    child: const Icon(Icons.broken_image, color: Color(0xFFCBD5E1)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isFirst)
                      const Text('Cover Photo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6)))
                    else
                      Text('Photo ${index + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF475569))),
                  ],
                ),
              ),
              // Move up/down buttons
              if (index > 0)
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 18, color: Color(0xFF64748B)),
                  onPressed: () => _reorderExistingPhoto(index, index - 1),
                  tooltip: 'Move up',
                  visualDensity: VisualDensity.compact,
                ),
              if (index < _existingPhotoUrls.length - 1)
                IconButton(
                  icon: const Icon(Icons.arrow_downward, size: 18, color: Color(0xFF64748B)),
                  onPressed: () => _reorderExistingPhoto(index, index + 2),
                  tooltip: 'Move down',
                  visualDensity: VisualDensity.compact,
                ),
              // Delete button
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Photo?'),
                      content: const Text('This will permanently delete this photo from storage.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _removeExistingPhoto(index);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
                tooltip: 'Delete photo',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageThumb(String path, VoidCallback? onRemove, {bool isLocal = false}) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: isLocal 
              ? (path.startsWith('http') || path.startsWith('blob:')
                  ? Image.network(path, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.image))
                  : const Icon(Icons.image, size: 48, color: Color(0xFFCBD5E1)))
              : Image.network(path, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.image)),
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: -4, right: -4,
            child: GestureDetector(
              onTap: onRemove,
              child: const CircleAvatar(radius: 10, backgroundColor: Color(0xFFEF4444), child: Icon(Icons.close, size: 12, color: Colors.white)),
            ),
          ),
      ],
    );
  }

  Widget _buildTaxInfo() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildTextField(
            controller: _hsnController,
            label: 'HSN Number',
            hint: 'Enter HSN number',
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _buildDropdownField<double>(
            label: 'GST Percent',
            value: (_selectedGstPercent != null && _gstRates.contains(_selectedGstPercent)) ? _selectedGstPercent : null,
            items: _gstRates.map((r) => DropdownMenuItem(value: r, child: Text('$r%'))).toList(),
            onChanged: (v) => setState(() => _selectedGstPercent = v),
            hint: 'Select GST %',
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, String? hint, bool required = false, Function(String)? onChanged, bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Color(0xFF334155)),
            children: [ if (required) const TextSpan(text: ' *', style: TextStyle(color: Colors.red)) ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          validator: required ? (v) => v == null || v.isEmpty ? 'Required' : null : null,
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>({required String label, T? value, required List<DropdownMenuItem<T>> items, required Function(T?) onChanged, String? hint, bool required = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Color(0xFF334155)),
            children: [ if (required) const TextSpan(text: ' *', style: TextStyle(color: Colors.red)) ],
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14, color: Colors.black),
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          validator: required ? (v) => v == null ? 'Required' : null : null,
        ),
      ],
    );
  }
}
