import 'package:supabase_flutter/supabase_flutter.dart';
import '../products/product_model.dart';

class InventoryService {
  final SupabaseClient supabase;
  InventoryService(this.supabase) {
    _initRealtime();
  }

  RealtimeChannel? _channel;

  void _initRealtime() {
    try {
      _channel = supabase
          .channel('inventory_sync_channel')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'orders',
            callback: (payload) async {
              final order = payload.newRecord;
              final orderId = order['id'] as String?;
              if (orderId == null) return;
              // For new orders reduce stock for each order item
              await _processOrderChange(orderId, decrease: true);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'orders',
            callback: (payload) async {
              final newOrder = payload.newRecord;
              final oldOrder = payload.oldRecord;
              final orderId = newOrder['id'] as String?;
              if (orderId == null) return;

              final newStatus = newOrder['order_status'] ?? newOrder['status'];
              final oldStatus = oldOrder['order_status'] ?? oldOrder['status'];

              // If order was cancelled after being placed, restore stock
              if (_isCancelledStatus(newStatus) && !_isCancelledStatus(oldStatus)) {
                await _processOrderChange(orderId, decrease: false);
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'returns',
            callback: (payload) async {
              final newReturn = payload.newRecord;
              final oldReturn = payload.oldRecord;
              final returnId = newReturn['id'] as String?;
              if (returnId == null) return;

              final newStatus = newReturn['return_status'];
              final oldStatus = oldReturn['return_status'];

              if (newStatus != oldStatus && (newStatus == 'approved' || newStatus == 'completed')) {
                // Restore returned quantities
                await _processReturnRestore(returnId);
              }
            },
          )
          .subscribe();
    } catch (e) {
      print('InventoryService realtime init error: $e');
    }
  }

  bool _isCancelledStatus(dynamic status) {
    if (status == null) return false;
    final s = status.toString().toLowerCase();
    return s.contains('cancel');
  }

  Future<void> _processOrderChange(String orderId, {required bool decrease}) async {
    try {
      final items = await supabase
          .from('order_items')
          .select('*')
          .eq('order_id', orderId) as List<dynamic>?;

      if (items == null) return;

      final user = supabase.auth.currentUser;
      final adminId = user?.id;

      for (final it in items) {
        final productId = it['product_id'] as String?;
        final qty = (it['quantity'] as num?)?.toInt() ?? 0;
        if (productId == null || qty == 0) continue;

        // Extract variation name from order item
        String qualityOption = '';
        if (it['quality_option_name'] != null) {
          qualityOption = it['quality_option_name'].toString();
        } else if (it['quality_option'] != null && it['quality_option'] is Map) {
          final qMap = it['quality_option'] as Map;
          qualityOption = (qMap['name'] ?? qMap['quality_option'] ?? qMap['option'] ?? '').toString();
        }

        final delta = decrease ? -qty : qty;

        try {
          final res = await supabase.rpc('adjust_inventory', params: {
            'p_product_id': productId,
            'p_quality_option': qualityOption,
            'p_delta': delta,
            'p_change_type': decrease ? 'reduce' : 'add',
            'p_reason': decrease ? 'Order placed' : 'Order cancelled',
            'p_admin': adminId,
            'p_source': orderId,
          });
          print('Inventory adjusted for $productId ($qualityOption): $res');
        } catch (e) {
          print('Failed to adjust inventory for $productId ($qualityOption): $e');
        }
      }
    } catch (e) {
      print('Error processing order change for $orderId: $e');
    }
  }

  Future<void> _processReturnRestore(String returnId) async {
    try {
      final items = await supabase
          .from('return_items')
          .select('*')
          .eq('return_id', returnId) as List<dynamic>?;

      if (items == null) return;

      final user = supabase.auth.currentUser;
      final adminId = user?.id;

      for (final it in items) {
        final productId = it['product_id'] as String?;
        final qty = (it['quantity'] as num?)?.toInt() ?? 0;
        if (productId == null || qty == 0) continue;

        // Extract variation name
        String qualityOption = '';
        if (it['quality_option_name'] != null) {
          qualityOption = it['quality_option_name'].toString();
        } else if (it['quality_option'] != null && it['quality_option'] is Map) {
          final qMap = it['quality_option'] as Map;
          qualityOption = (qMap['name'] ?? qMap['quality_option'] ?? qMap['option'] ?? '').toString();
        }

        try {
          final res = await supabase.rpc('adjust_inventory', params: {
            'p_product_id': productId,
            'p_quality_option': qualityOption,
            'p_delta': qty,
            'p_change_type': 'add',
            'p_reason': 'Return approved',
            'p_admin': adminId,
            'p_source': returnId,
          });
          print('Inventory restored for $productId ($qualityOption): $res');
        } catch (e) {
          print('Failed to restore inventory for $productId ($qualityOption): $e');
        }
      }
    } catch (e) {
      print('Error processing return restore for $returnId: $e');
    }
  }

  // Fetch inventory list grouped by product
  Future<List<dynamic>> fetchInventory() async {
    try {
      // First, get all products with their brand info, stock_status and variations
      final productsRes = await supabase
          .from('products')
          .select('''
            id,
            product_id,
            product_name,
            category,
            subcategory,
            stock_status,
            brand_ids,
            quality_options,
            brands(id, name)
          ''')
          .order('product_name');
      
      final products = productsRes as List<dynamic>;
      
      // Try to get inventory data
      // Key format: "product_id:variation_name"
      Map<String, Map<String, dynamic>> inventoryMap = {};
      try {
        final inventoryRes = await supabase
            .from('inventory')
            .select('*');
        
        final inventoryList = inventoryRes as List<dynamic>;
        
        for (final inv in inventoryList) {
          final pId = inv['product_id']?.toString() ?? '';
          final qOpt = inv['quality_option']?.toString() ?? '';
          if (pId.isNotEmpty) {
            inventoryMap['$pId:$qOpt'] = inv as Map<String, dynamic>;
          }
        }
      } catch (e) {
        print('Note: Could not fetch inventory table: $e');
      }
      
      // Merge products with inventory data
      final result = <Map<String, dynamic>>[];
      for (final row in products) {
        // Use Product model for consistent parsing
        final product = Product.fromJson(row as Map<String, dynamic>);
        
        final productId = product.id;
        final skuId = product.productId ?? productId;
        final stockStatus = product.stockStatus;
        
        // Extract brand name from parsed product
        String brandName = product.brandNames.isNotEmpty ? product.brandNames.first : '';

        final productVariants = <Map<String, dynamic>>[];
        final Set<String> processedVariations = {};

        // 1. Add rows for each defined variation in product JSON
        if (product.qualityOptions.isEmpty) {
          _addVariationToList(productVariants, product, inventoryMap, '', productId, skuId, stockStatus);
          processedVariations.add('');
        } else {
          for (final opt in product.qualityOptions) {
            final optName = opt.name.trim();
            _addVariationToList(productVariants, product, inventoryMap, optName, productId, skuId, stockStatus);
            processedVariations.add(optName.toLowerCase());
          }
        }

        // 2. Add any existing inventory variations that are NOT defined in the product JSON (Manual variations)
        inventoryMap.forEach((key, inv) {
          if (key.startsWith('$productId:')) {
            String vName = key.substring('$productId:'.length);
            if (!processedVariations.contains(vName.toLowerCase().trim())) {
              _addVariationToList(productVariants, product, inventoryMap, vName, productId, skuId, stockStatus);
              processedVariations.add(vName.toLowerCase().trim());
            }
          }
        });

        // Normalize Category Name
        String rawCategory = (product.category ?? '').trim();
        String normalizedCategory = rawCategory;
        if (rawCategory.isNotEmpty) {
          // Heuristic: If we have "Chemicals" and "Chemical", merge them.
          // We'll use the plural version as canonical if both exist, or just the one we find.
          // For now, let's just trim and capitalize first letter
          if (rawCategory.length > 1) {
             normalizedCategory = rawCategory[0].toUpperCase() + rawCategory.substring(1);
          }
        } else {
          normalizedCategory = 'Other';
        }

        result.add({
          'id': productId,
          'product_id': skuId,
          'product_name': product.productName,
          'brand_name': brandName,
          'category': normalizedCategory,
          'subcategory': product.subcategory ?? '',
          'stock_status': row['stock_status'] ?? 'in_stock',
          'variants': productVariants,
          'quality_options': row['quality_options'], // Original options for reference in dialogs if needed
        });
      }
      
      return result;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('relation "public.inventory" does not exist') || msg.contains('relation "inventory" does not exist')) {
        throw Exception('Inventory table not found. Please run the SQL migration.');
      }
      rethrow;
    }
  }

  void _addVariationToList(
    List<Map<String, dynamic>> list,
    Product product,
    Map<String, Map<String, dynamic>> inventoryMap,
    String variation,
    String productId,
    String skuId,
    String stockStatus,
  ) {
    final invKey = '$productId:$variation';
    final inventory = inventoryMap[invKey];
    bool hasInventoryEntry = inventory != null;

    int currentStock = 0;
    if (hasInventoryEntry) {
      currentStock = (inventory['current_stock'] as num?)?.toInt() ?? 0;
    } else if (stockStatus == 'in_stock') {
      currentStock = -1; // Special marker for "In Stock (quantity untracked)"
    }

    list.add({
      'variation': variation,
      'sku': skuId,
      'current_stock': currentStock,
      'has_inventory_entry': hasInventoryEntry,
      'low_stock_threshold': inventory?['low_stock_threshold'] ?? 5,
      'last_updated': inventory?['last_updated']?.toString() ?? '',
    });
  }

  // Manual adjust (used by UI)
  Future<dynamic> adjustStock({
    required String productId, 
    required String qualityOption,
    required int delta, 
    required String reason
  }) async {
    try {
      final adminId = supabase.auth.currentUser?.id;
      final res = await supabase.rpc('adjust_inventory', params: {
        'p_product_id': productId,
        'p_quality_option': qualityOption,
        'p_delta': delta.toInt() == 0 ? 0 : delta.toInt(),
        'p_change_type': delta >= 0 ? 'add' : 'reduce',
        'p_reason': reason,
        'p_admin': adminId,
        'p_source': null,
      });
      return res;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('adjust_inventory')) {
        throw Exception('Inventory RPC error: $e');
      }
      rethrow;
    }
  }

  // Delete inventory entry
  Future<void> deleteInventoryVariation(String productId, String qualityOption) async {
    try {
      await supabase
          .from('inventory')
          .delete()
          .match({
            'product_id': productId,
            'quality_option': qualityOption,
          });
    } catch (e) {
      print('Error deleting inventory variation: $e');
      rethrow;
    }
  }

  // Mark a specific variation as out of stock
  Future<void> markOutOfStock(String productId, String qualityOption) async {
    try {
      // Find current stock first to calculate delta
      final res = await supabase
          .from('inventory')
          .select('current_stock')
          .match({'product_id': productId, 'quality_option': qualityOption})
          .maybeSingle();
      
      int currentStock = 0;
      if (res != null) {
        currentStock = (res['current_stock'] as num?)?.toInt() ?? 0;
      }
      
      // If no entry exists, we must create one with 0 stock
      // adjustStock handles creation via RPC if it uses upsert logic
      
      await adjustStock(
        productId: productId,
        qualityOption: qualityOption,
        delta: currentStock == 0 ? 0 : -currentStock,
        reason: 'Marked Out of Stock Manually',
      );
    } catch (e) {
      print('Error marking out of stock: $e');
      rethrow;
    }
  }

  // Mark a specific variation as in stock (sets to default 50)
  Future<void> markInStock(String productId, String qualityOption) async {
    try {
      // Find current stock first to see if we need to adjust
      final res = await supabase
          .from('inventory')
          .select('current_stock')
          .match({'product_id': productId, 'quality_option': qualityOption})
          .maybeSingle();
      
      int currentStock = 0;
      if (res != null) {
        currentStock = (res['current_stock'] as num?)?.toInt() ?? 0;
      }

      // If already has stock, do nothing, otherwise add 50
      if (currentStock <= 0) {
        await adjustStock(
          productId: productId,
          qualityOption: qualityOption,
          delta: 50,
          reason: 'Marked In Stock Manually',
        );
      }
    } catch (e) {
      print('Error marking in stock: $e');
      rethrow;
    }
  }

  // Toggle whole product stock status
  Future<void> toggleProductStockStatus(String productId, String currentStatus) async {
    try {
      final newStatus = currentStatus == 'out_of_stock' ? 'in_stock' : 'out_of_stock';
      await supabase
          .from('products')
          .update({'stock_status': newStatus})
          .eq('id', productId);
    } catch (e) {
      print('Error toggling product stock status: $e');
      rethrow;
    }
  }
}
