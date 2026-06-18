import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart'; // Ensure access to supabaseProvider
import '../categories/category_model.dart';
import '../categories/categories_notifier_provider.dart';
import 'brands_provider.dart';

class AddEditBrandDialog extends ConsumerStatefulWidget {
  final Brand? brand;

  const AddEditBrandDialog({super.key, this.brand});

  @override
  ConsumerState<AddEditBrandDialog> createState() => _AddEditBrandDialogState();
}

class _AddEditBrandDialogState extends ConsumerState<AddEditBrandDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedCategoryName;
  final _logoUrlController = TextEditingController();
  final _catalogUrlController = TextEditingController();
  final _picker = ImagePicker();
  bool _isActive = true;
  bool _saving = false;
  XFile? _selectedLogoFile;
  PlatformFile? _selectedCatalogFile;

  @override
  void initState() {
    super.initState();
    if (widget.brand != null) {
      _nameController.text = widget.brand!.name;
      _selectedCategoryName = widget.brand!.description;
      _logoUrlController.text = widget.brand!.logo ?? '';
      _catalogUrlController.text = widget.brand!.catalogPdfUrl ?? '';
      _isActive = widget.brand!.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _logoUrlController.dispose();
    _catalogUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickLogoImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedLogoFile = pickedFile;
        _logoUrlController.clear();
      });
    }
  }

  Future<void> _pickCatalogPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedCatalogFile = result.files.first;
        _catalogUrlController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.brand == null ? 'Add Brand' : 'Edit Brand'),
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
                    labelText: 'Brand Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter brand name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Consumer(
                  builder: (context, ref, _) {
                    final categoriesAsync = ref.watch(categoriesNotifierProvider);
                    return categoriesAsync.when(
                      data: (categories) {
                        // Build unique category names list
                        final categoryNames = categories
                            .map((c) => c.name)
                            .toSet()
                            .toList()
                          ..sort();

                        // Validate selected value exists in the list
                        String? dropdownValue = _selectedCategoryName;
                        if (dropdownValue != null && !categoryNames.contains(dropdownValue)) {
                          // Try case-insensitive match
                          final match = categoryNames.cast<String?>().firstWhere(
                            (name) => name?.toLowerCase().trim() == dropdownValue!.toLowerCase().trim(),
                            orElse: () => null,
                          );
                          dropdownValue = match;
                          if (dropdownValue != _selectedCategoryName) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() => _selectedCategoryName = dropdownValue);
                            });
                          }
                        }

                        return DropdownButtonFormField<String>(
                          value: dropdownValue,
                          decoration: const InputDecoration(
                            labelText: 'Category *',
                            border: OutlineInputBorder(),
                          ),
                          hint: const Text('Select category...'),
                          isExpanded: true,
                          items: categoryNames
                              .map((name) => DropdownMenuItem(
                                    value: name,
                                    child: Text(name),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCategoryName = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a category';
                            }
                            return null;
                          },
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Error loading categories: $e',
                          style: const TextStyle(color: Colors.red)),
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Logo Upload Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Brand Logo',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Show current logo preview or upload area
                    if (_selectedLogoFile != null || _logoUrlController.text.isNotEmpty) ...[
                      // Logo preview with change/remove buttons
                      Container(
                        width: double.infinity,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            // Logo preview
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                                color: Colors.white,
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                                child: _selectedLogoFile != null
                                    ? FutureBuilder<dynamic>(
                                        future: _selectedLogoFile!.readAsBytes(),
                                        builder: (context, snapshot) {
                                          if (snapshot.hasData) {
                                            return Image.memory(snapshot.data!, fit: BoxFit.cover);
                                          }
                                          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                                        },
                                      )
                                    : Image.network(
                                        _logoUrlController.text,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40, color: Color(0xFFCBD5E1)),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Actions
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedLogoFile != null ? _selectedLogoFile!.name : 'Current logo',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: _pickLogoImage,
                                        icon: const Icon(Icons.upload_file, size: 16),
                                        label: const Text('Change'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF3B82F6),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          textStyle: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _selectedLogoFile = null;
                                            _logoUrlController.clear();
                                          });
                                        },
                                        icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                                        label: const Text('Remove', style: TextStyle(color: Color(0xFFEF4444))),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          textStyle: const TextStyle(fontSize: 12),
                                          side: const BorderSide(color: Color(0xFFEF4444)),
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
                    ] else ...[
                      // Empty state - upload prompt
                      InkWell(
                        onTap: _pickLogoImage,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          height: 100,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4), style: BorderStyle.solid),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, size: 32, color: const Color(0xFF3B82F6).withValues(alpha: 0.7)),
                              const SizedBox(height: 8),
                              const Text('Click to upload logo', style: TextStyle(fontSize: 13, color: Color(0xFF3B82F6), fontWeight: FontWeight.w500)),
                              const Text('PNG, JPG, WEBP', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // URL fallback
                      TextFormField(
                        controller: _logoUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Or paste logo URL',
                          border: OutlineInputBorder(),
                          hintText: 'https://example.com/logo.png',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          isDense: true,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                // Catalog PDF Upload Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Catalog PDF',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_selectedCatalogFile != null || (_catalogUrlController.text.isNotEmpty))
                          const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _catalogUrlController,
                      decoration: InputDecoration(
                        labelText: 'Catalog PDF URL (Optional)',
                        border: const OutlineInputBorder(),
                        hintText: 'https://example.com/catalog.pdf',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        suffixIcon: IconButton(
                          onPressed: _pickCatalogPdf,
                          icon: Icon(
                            Icons.picture_as_pdf,
                            color: _selectedCatalogFile == null ? const Color(0xFFEF4444) : Colors.green,
                          ),
                          tooltip: _selectedCatalogFile == null ? 'Upload Catalog' : 'Change Catalog',
                        ),
                      ),
                      enabled: _selectedCatalogFile == null,
                    ),
                    if (_selectedCatalogFile != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.picture_as_pdf, size: 16, color: Colors.red),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _selectedCatalogFile!.name,
                                style: const TextStyle(fontSize: 12, color: Colors.green),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16, color: Colors.red),
                              onPressed: () => setState(() => _selectedCatalogFile = null),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Active'),
                  subtitle: const Text('Brand will be visible to users'),
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
          onPressed: _saving ? null : _saveBrand,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.brand == null ? 'Add' : 'Update'),
        ),
      ],
    );
  }

  Future<void> _saveBrand() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final supabase = ref.read(supabaseProvider);
      String? logoUrl = _logoUrlController.text.trim().isEmpty 
          ? widget.brand?.logo 
          : _logoUrlController.text.trim();
      String? catalogUrl = _catalogUrlController.text.trim().isEmpty 
          ? widget.brand?.catalogPdfUrl 
          : _catalogUrlController.text.trim();

      // Upload logo if a new file was selected
      if (_selectedLogoFile != null) {
        try {
          print('AddEditBrandDialog: Uploading logo image...');
          final bytes = await _selectedLogoFile!.readAsBytes();
          final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_selectedLogoFile!.name}';
          final path = 'brands/logos/$fileName';
          
          final fileExt = _selectedLogoFile!.name.split('.').last;
          await supabase.storage.from('brand-assets').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$fileExt', upsert: true),
          );
          
          logoUrl = supabase.storage.from('brand-assets').getPublicUrl(path);
          print('AddEditBrandDialog: Logo uploaded successfully: $logoUrl');
        } catch (e) {
          print('AddEditBrandDialog: Storage upload failed (bucket may not exist): $e');
          print('AddEditBrandDialog: Continuing without logo upload. Use URL field instead.');
          // Continue without logo upload - user can use URL field
        }
      }

      // Upload catalog PDF if a new file was selected
      if (_selectedCatalogFile != null) {
        try {
          print('AddEditBrandDialog: Uploading catalog PDF...');
          final bytes = _selectedCatalogFile!.bytes;
          if (bytes != null) {
            final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_selectedCatalogFile!.name}';
            final path = 'brands/catalogs/$fileName';
            
            await supabase.storage.from('brand-assets').uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
            );
            
            catalogUrl = supabase.storage.from('brand-assets').getPublicUrl(path);
            print('AddEditBrandDialog: Catalog uploaded successfully: $catalogUrl');
          }
        } catch (e) {
          print('AddEditBrandDialog: Storage upload failed (bucket may not exist): $e');
          print('AddEditBrandDialog: Continuing without catalog upload. Use URL field instead.');
          // Continue without catalog upload - user can use URL field
        }
      }

      print('AddEditBrandDialog: Creating brand object...');
      final brand = Brand(
        id: widget.brand?.id ?? '',
        name: _nameController.text.trim(),
        description: _selectedCategoryName,
        logo: logoUrl,
        catalogPdfUrl: catalogUrl,
        isActive: _isActive,
        createdAt: widget.brand?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      print('AddEditBrandDialog: Brand object created: ${brand.name}');
      
      if (widget.brand == null) {
        print('AddEditBrandDialog: Adding new brand...');
        await ref.read(brandsNotifierProvider.notifier).addBrand(brand);
        print('AddEditBrandDialog: Brand added successfully');
        if (!mounted) return;
        Navigator.of(context).pop();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Brand added successfully')),
          );
        }
      } else {
        print('AddEditBrandDialog: Updating brand...');
        await ref.read(brandsNotifierProvider.notifier).updateBrand(brand);
        print('AddEditBrandDialog: Brand updated successfully');
        if (!mounted) return;
        Navigator.of(context).pop();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Brand updated successfully')),
          );
        }
      }
    } catch (e, stackTrace) {
      print('AddEditBrandDialog: Error saving brand: $e');
      print('AddEditBrandDialog: Stack trace: $stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
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

