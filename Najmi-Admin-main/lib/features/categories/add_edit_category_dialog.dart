import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import 'category_model.dart';
import 'categories_notifier_provider.dart';

class AddEditCategoryDialog extends ConsumerStatefulWidget {
  final Category? category;

  const AddEditCategoryDialog({super.key, this.category});

  @override
  ConsumerState<AddEditCategoryDialog> createState() => _AddEditCategoryDialogState();
}

class _AddEditCategoryDialogState extends ConsumerState<AddEditCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCategoryName;
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _gstController = TextEditingController();
  bool _isActive = true;
  bool _saving = false;
  XFile? _imageFile;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _selectedCategoryName = widget.category!.name;
      _descriptionController.text = widget.category!.description ?? '';
      _imageUrlController.text = widget.category!.imageUrl ?? '';
      _isActive = widget.category!.isActive;
      _gstController.text = widget.category!.gstPercent != null
          ? widget.category!.gstPercent!.toStringAsFixed(0)
          : '';
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _gstController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _imageFile = image;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category == null ? 'Add Category' : 'Edit Category'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                const Text('Category Image', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 80,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade100,
                    ),
                    child: _imageFile != null
                        ? Row(
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  bottomLeft: Radius.circular(8),
                                ),
                                child: Image.network(
                                  _imageFile!.path,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _imageFile!.name,
                                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.edit, size: 18, color: Colors.grey),
                              const SizedBox(width: 12),
                            ],
                          )
                        : (widget.category?.imageUrl != null && widget.category!.imageUrl!.isNotEmpty)
                            ? Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(8),
                                      bottomLeft: Radius.circular(8),
                                    ),
                                    child: Image.network(
                                      widget.category!.imageUrl!,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.broken_image, size: 32, color: Colors.grey),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'Tap to change image',
                                      style: TextStyle(fontSize: 13, color: Colors.grey),
                                    ),
                                  ),
                                  const Icon(Icons.edit, size: 18, color: Colors.grey),
                                  const SizedBox(width: 12),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate, size: 28, color: Colors.grey),
                                  SizedBox(width: 8),
                                  Text('Click to select image', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                ],
                              ),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Active'),
                  subtitle: const Text('Category will be visible to users'),
                  value: _isActive,
                  onChanged: (value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _gstController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Default GST % for this Category',
                    hintText: 'e.g. 5, 12, or 18',
                    suffixText: '%',
                    border: OutlineInputBorder(),
                    helperText:
                        'Used as fallback if a product has no GST set individually',
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final parsed = double.tryParse(value);
                      if (parsed == null || parsed < 0 || parsed > 100) {
                        return 'Enter a valid GST % between 0 and 100';
                      }
                    }
                    return null;
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
          onPressed: _saving ? null : _saveCategory,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.category == null ? 'Add' : 'Update'),
        ),
      ],
    );
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      String? imageUrl = widget.category?.imageUrl;

      if (_imageFile != null) {
        print('AddEditCategoryDialog: Uploading image...');
        try {
          final supabase = ref.read(supabaseProvider);
          final bytes = await _imageFile!.readAsBytes();
          final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_imageFile!.name}';
          final path = 'categories/$fileName';

          final fileExt = _imageFile!.name.split('.').last;
          await supabase.storage.from('category-images').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$fileExt', upsert: true),
          );

          imageUrl = supabase.storage.from('category-images').getPublicUrl(path);
          print('AddEditCategoryDialog: Image uploaded successfully: $imageUrl');
        } catch (uploadError) {
          print('AddEditCategoryDialog: Image upload failed (bucket may not exist): $uploadError');
          // Save category without image — show warning after save
          imageUrl = null;
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '⚠️ Image could not be uploaded (storage bucket not found). Category will be saved without an image.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
      }

      print('AddEditCategoryDialog: Creating category object...');
      final category = Category(
        id: widget.category?.id ?? '',
        name: _selectedCategoryName ?? '',
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        imageUrl: imageUrl,
        isActive: _isActive,
        createdAt: widget.category?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        gstPercent: double.tryParse(_gstController.text.trim()),
      );

      print('AddEditCategoryDialog: Category object created: ${category.name}');
      
      if (widget.category == null) {
        print('AddEditCategoryDialog: Adding new category...');
        await ref.read(categoriesNotifierProvider.notifier).addCategory(category);
        print('AddEditCategoryDialog: Category added successfully');
        if (!mounted) return;
        Navigator.of(context).pop();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category added successfully')),
          );
        }
      } else {
        print('AddEditCategoryDialog: Updating category...');
        await ref.read(categoriesNotifierProvider.notifier).updateCategory(category);
        print('AddEditCategoryDialog: Category updated successfully');
        if (!mounted) return;
        Navigator.of(context).pop();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category updated successfully')),
          );
        }
      }
    } catch (e, stackTrace) {
      print('AddEditCategoryDialog: Error saving category: $e');
      print('AddEditCategoryDialog: Stack trace: $stackTrace');
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

