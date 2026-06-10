import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../main.dart';
import '../../core/widgets/action_menu_item.dart';
import 'categories_notifier_provider.dart';
import 'category_model.dart';
import 'add_edit_category_dialog.dart';
import 'category_products_screen.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Force a refresh when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(categoriesNotifierProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesNotifierProvider);
    print('CategoriesScreen: Building with state: ${categoriesAsync.runtimeType}');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Categories Management'),
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
                      hintText: 'Search categories...',
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
                  width: 160,
                  child: ElevatedButton.icon(
                    onPressed: () => _showAddCategoryDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Category', style: TextStyle(fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Categories List
          Expanded(
            child: categoriesAsync.when(
              data: (categories) {
                print('CategoriesScreen: Received ${categories.length} categories');
                final filteredCategories = _searchQuery.isEmpty
                    ? categories
                    : categories.where((category) =>
                        category.name.toLowerCase().contains(_searchQuery) ||
                        (category.description?.toLowerCase().contains(_searchQuery) ?? false)).toList();

                print('CategoriesScreen: Filtered to ${filteredCategories.length} categories');
                
                if (filteredCategories.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.category_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? 'No Categories Found' : 'No categories match your search',
                          style: TextStyle(color: Colors.grey[500], fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isEmpty 
                              ? 'Click "Add Category" to get started' 
                              : 'Try a different search term',
                          style: TextStyle(color: Colors.grey[400], fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                // Table-style layout similar to the web admin (Name, Description,
                // Subcategories, Status, Product Count, Created At, Actions)
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: SingleChildScrollView(
                    // Vertical scrolling for when there are many categories.
                    scrollDirection: Axis.vertical,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                        columnSpacing: 24,
                        // Use the same height for heading and data rows, and make sure
                        // dataRowMinHeight <= dataRowMaxHeight to avoid non-normalized
                        // BoxConstraints.
                        headingRowHeight: 56,
                        dataRowMinHeight: 56,
                        dataRowMaxHeight: 56,
                        columns: const [
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Description')),
                          DataColumn(label: Text('Subcategories')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Product Count')),
                          DataColumn(label: Text('GST %')),
                          DataColumn(label: Text('Discount')),
                          DataColumn(label: Text('Created At')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: filteredCategories.map((category) {
                          final subcats = category.subcategories;
                          final subcatsPreview = subcats.isEmpty
                              ? 'No subcategories'
                              : [
                                  ...subcats.take(3),
                                  if (subcats.length > 3)
                                    '+${subcats.length - 3} more',
                                ].join(', ');
                          return DataRow(
                            cells: [
                              DataCell(Text(
                                category.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              )),
                              DataCell(
                                SizedBox(
                                  width: 220,
                                  child: Text(
                                    category.description ?? '-',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 260,
                                  child: Text(
                                    subcatsPreview,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: category.isActive
                                        ? Colors.green[100]
                                        : Colors.red[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    category.isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      color: category.isActive
                                          ? Colors.green[700]
                                          : Colors.red[700],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(Text(category.productCount.toString())),
                              // GST %
                              DataCell(
                                category.gstPercent != null
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${category.gstPercent!.toStringAsFixed(0)}%',
                                          style: const TextStyle(
                                            color: Color(0xFF1D4ED8),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      )
                                    : const Text('—',
                                        style: TextStyle(color: Colors.grey)),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 120,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showCategoryDiscountDialog(category),
                                    icon: const Icon(Icons.percent, size: 16),
                                    label: const Text(
                                      'Set',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(Text(
                                DateFormat('yyyy-MM-dd')
                                    .format(category.createdAt),
                              )),
                              DataCell(
                                PopupMenuButton<String>(
                                  tooltip: 'Actions',
                                  onSelected: (value) async {
                                    if (value == 'view') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              CategoryProductsScreen(
                                            categoryName: category.name,
                                            categoryId: category.id,
                                          ),
                                        ),
                                      );
                                    } else if (value == 'edit') {
                                      _showEditCategoryDialog(context, category);
                                    } else if (value == 'toggle') {
                                      _toggleCategoryStatus(context, category);
                                    } else if (value == 'delete') {
                                      _deleteCategory(context, category);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'view',
                                      child: ActionMenuItem(
                                        icon: Icons.inventory_2_outlined,
                                        label: 'View Products',
                                        color: Color(0xFF0369A1),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: ActionMenuItem(
                                        icon: Icons.edit_outlined,
                                        label: 'Edit',
                                        color: Color(0xFF1D4ED8),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'toggle',
                                      child: ActionMenuItem(
                                        icon: category.isActive
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        label: category.isActive
                                            ? 'Deactivate'
                                            : 'Activate',
                                        color: category.isActive
                                            ? Colors.orange
                                            : Colors.green,
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: ActionMenuItem(
                                        icon: Icons.delete_outline,
                                        label: 'Delete',
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                  child: const ActionMenuTrigger(),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ));
              },
              loading: () {
                print('CategoriesScreen: Loading state');
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading categories...'),
                    ],
                  ),
                );
              },
              error: (err, stack) {
                print('CategoriesScreen: Error loading categories: $err');
                print('CategoriesScreen: Stack trace: $stack');
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        const Text(
                          'Error loading categories',
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
                            print('CategoriesScreen: Retry button pressed');
                            ref.invalidate(categoriesNotifierProvider);
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
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

  Widget _buildCategoryCard(BuildContext context, Category category) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CategoryProductsScreen(
                categoryName: category.name,
                categoryId: category.id,
              ),
            ),
          );
        },
          leading: CircleAvatar(
            radius: 30,
            backgroundColor: Colors.grey[200],
            child: category.imageUrl != null
                ? ClipOval(
                    child: Image.network(
                      category.imageUrl!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.category, size: 30),
                    ),
                  )
                : const Icon(Icons.category, size: 30),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  category.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: category.isActive ? Colors.green[100] : Colors.red[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  category.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: category.isActive ? Colors.green[700] : Colors.red[700],
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
              if (category.description != null && category.description!.isNotEmpty)
                Text(
                  category.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CategoryProductsScreen(
                        categoryName: category.name,
                        categoryId: category.id,
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
                () => _showEditCategoryDialog(context, category),
              ),
            ),
            PopupMenuItem(
              child: Row(
                children: [
                  Icon(
                    category.isActive ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(category.isActive ? 'Deactivate' : 'Activate'),
                ],
              ),
              onTap: () => Future.delayed(
                const Duration(milliseconds: 100),
                () => _toggleCategoryStatus(context, category),
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
                () => _deleteCategory(context, category),
              ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    print('CategoriesScreen: Opening add category dialog');
    try {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          print('CategoriesScreen: Dialog builder called');
          return AddEditCategoryDialog();
        },
      ).then((_) {
        print('CategoriesScreen: Dialog closed');
      }).catchError((error) {
        print('CategoriesScreen: Error showing dialog: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening dialog: $error')),
        );
      });
    } catch (e) {
      print('CategoriesScreen: Exception showing dialog: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showEditCategoryDialog(BuildContext context, Category category) {
    print('CategoriesScreen: Opening edit category dialog for: ${category.name}');
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AddEditCategoryDialog(category: category),
    ).then((_) {
      print('CategoriesScreen: Edit dialog closed');
    });
  }

  void _toggleCategoryStatus(BuildContext context, Category category) {
    ref.read(categoriesNotifierProvider.notifier).toggleCategoryStatus(
      category.id,
      !category.isActive,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Category ${category.isActive ? 'deactivated' : 'activated'} successfully'),
      ),
    );
  }

  void _deleteCategory(BuildContext context, Category category) async {
    // Step 1: Fetch live product count
    int productCount = category.productCount;
    try {
      final supabase = ref.read(supabaseProvider);
      final response = await supabase
          .from('products')
          .select('id')
          .eq('category', category.name);
      productCount = (response as List).length;
    } catch (_) {}

    if (!context.mounted) return;

    final confirmController = TextEditingController();
    bool confirmed = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(builder: (ctx, setDialogState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.warning_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            const Text('Delete Category', style: TextStyle(color: Colors.red)),
          ]),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (productCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[300]!),
                    ),
                    child: Row(children: [
                      Icon(Icons.inventory_2, color: Colors.red[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '⚠️  This category has $productCount product${productCount == 1 ? '' : 's'} that will also be permanently deleted!',
                          style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'This action CANNOT be undone. To confirm, type the category name below:',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: category.name,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ] else
                  Text(
                    'Are you sure you want to delete "${category.name}"?\n\nThis category has no products. This action cannot be undone.',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: (productCount == 0 || confirmController.text.trim() == category.name)
                  ? () { confirmed = true; Navigator.pop(dialogContext); }
                  : null,
              icon: const Icon(Icons.delete_forever, size: 18),
              label: const Text('Delete Permanently'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
              ),
            ),
          ],
        );
      }),
    );

    if (!confirmed) return;

    try {
      await ref.read(categoriesNotifierProvider.notifier).deleteCategory(category.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Category "${category.name}" deleted'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting category: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }


  void _showCategoryDiscountDialog(Category category) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Apply Discount - ${category.name}'),
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
                await _applyDiscountToCategory(category, value);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _applyDiscountToCategory(
      Category category, double discountPercent) async {
    try {
      final supabase = ref.read(supabaseProvider);

      // Fetch products in this category with their MRP values
      final response = await supabase
          .from('products')
          .select('id, mrp')
          .eq('category', category.name);

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
                ? 'No products found in ${category.name} to apply discount.'
                : 'Applied $discountPercent% discount to ${products.length} products in ${category.name}',
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
