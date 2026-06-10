import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import 'add_product_dialog.dart';

class BrandProductsScreen extends ConsumerStatefulWidget {
  final String brandId;
  final String brandName;

  const BrandProductsScreen({
    super.key,
    required this.brandId,
    required this.brandName,
  });

  @override
  ConsumerState<BrandProductsScreen> createState() => _BrandProductsScreenState();
}

class _BrandProductsScreenState extends ConsumerState<BrandProductsScreen> {
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
      
      // Get products where brand_id matches OR brand is in brand_ids array
      final response = await supabase
          .from('products')
          .select('*')
          .or('brand_id.eq.${widget.brandId},brand_ids.cs.["${widget.brandId}"]')
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
        title: Text('Products - ${widget.brandName}'),
        backgroundColor: Colors.white,
        elevation: 0,
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
                            'Add products to this brand',
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
            if (product['category'] != null)
              Text('Category: ${product['category']}'),
            if (product['mrp'] != null)
              Text('MRP: ₹${product['mrp']}'),
            if (product['final_price'] != null)
              Text('Price: ₹${product['final_price']}'),
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
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _showEditProductDialog(context, product);
            } else if (value == 'delete') {
              _showDeleteConfirmation(context, product);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
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

  void _showAddProductDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddProductDialog(brandId: widget.brandId),
    ).then((_) => _loadProducts());
  }

  void _showEditProductDialog(BuildContext context, Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => AddProductDialog(
        brandId: widget.brandId,
        product: product,
      ),
    ).then((_) => _loadProducts());
  }

  Future<void> _showDeleteConfirmation(BuildContext context, Map<String, dynamic> product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product['product_name']}"?'),
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

    if (confirm == true) {
      await _deleteProduct(product['id']);
    }
  }

  Future<void> _deleteProduct(String productId) async {
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.from('products').delete().eq('id', productId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product deleted successfully')),
        );
      }
      _loadProducts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting product: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

