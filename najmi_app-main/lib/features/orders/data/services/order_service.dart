import 'package:contracto_app/core/network/supabase_service.dart';
import 'package:contracto_app/features/orders/data/models/order_model.dart';

class OrderService {
  Future<List<OrderModel>> getUserOrders() async {
    try {
      final authUser = SupabaseService.instance.currentUser;
      if (authUser == null) {
        throw Exception('User not authenticated');
      }

      // Resolve public user ID
      final userData = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('email', authUser.email!)
          .maybeSingle();

      final userId = userData != null ? userData['id'] : authUser.id;

      // Fetch orders from the orders table
      final response = await SupabaseService.client
          .from('orders')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      // Parse orders
      final orders = response.map((order) => OrderModel.fromJson(order)).toList();

      // ── Photo backfill ───────────────────────────────────────────────────────
      // For items that were created from quotes without an image_url, look up
      // the product's photos array from the products table and inject the first photo.
      final Set<String> missingProductIds = {};
      for (final order in orders) {
        for (final item in order.items) {
          if ((item.imageUrl == null || item.imageUrl!.isEmpty) &&
              item.productId.isNotEmpty) {
            missingProductIds.add(item.productId);
          }
        }
      }

      Map<String, String> productPhotoMap = {};
      if (missingProductIds.isNotEmpty) {
        try {
          final productsResponse = await SupabaseService.client
              .from('products')
              .select('id, photos')
              .inFilter('id', missingProductIds.toList());

          for (final product in productsResponse) {
            final photos = product['photos'];
            if (photos is List && photos.isNotEmpty) {
              productPhotoMap[product['id'].toString()] =
                  photos.first.toString();
            }
          }
        } catch (e) {
          print('Note: Could not fetch product photos for backfill: $e');
        }
      }

      if (productPhotoMap.isEmpty) return orders;

      // Rebuild orders with the backfilled image URLs
      return orders.map((order) {
        final needsUpdate = order.items.any(
          (item) =>
              (item.imageUrl == null || item.imageUrl!.isEmpty) &&
              productPhotoMap.containsKey(item.productId),
        );
        if (!needsUpdate) return order;

        final updatedItems = order.items.map((item) {
          if ((item.imageUrl == null || item.imageUrl!.isEmpty) &&
              productPhotoMap.containsKey(item.productId)) {
            return OrderItemModel(
              productId: item.productId,
              productName: item.productName,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
              totalPrice: item.totalPrice,
              qualityOptionId: item.qualityOptionId,
              qualityOptionName: item.qualityOptionName,
              unit: item.unit,
              isReturnable: item.isReturnable,
              imageUrl: productPhotoMap[item.productId],
            );
          }
          return item;
        }).toList();

        return OrderModel(
          id: order.id,
          userId: order.userId,
          customerName: order.customerName,
          customerEmail: order.customerEmail,
          customerPhone: order.customerPhone,
          deliveryAddress: order.deliveryAddress,
          paymentMethod: order.paymentMethod,
          paymentStatus: order.paymentStatus,
          status: order.status,
          deliveryType: order.deliveryType,
          notes: order.notes,
          gstNumber: order.gstNumber,
          totalAmount: order.totalAmount,
          subtotal: order.subtotal,
          gstAmount: order.gstAmount,
          deliveryCharge: order.deliveryCharge,
          invoiceRequired: order.invoiceRequired,
          createdAt: order.createdAt,
          updatedAt: order.updatedAt,
          items: updatedItems,
          estimatedDelivery: order.estimatedDelivery,
          trackingMilestones: order.trackingMilestones,
          statusNotes: order.statusNotes,
          deliveredAt: order.deliveredAt,
          paymentDueDate: order.paymentDueDate,
          paymentSource: order.paymentSource,
          paymentDueDays: order.paymentDueDays,
          transactionId: order.transactionId,
        );
      }).toList();
      // ────────────────────────────────────────────────────────────────────────
        } catch (e) {
      throw Exception('Error fetching orders: $e');
    }
  }

  Future<OrderModel?> getOrderById(String orderId) async {
    try {
      final authUser = SupabaseService.instance.currentUser;
      if (authUser == null) {
        throw Exception('User not authenticated');
      }

      // Resolve public user ID
      final userData = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('email', authUser.email!)
          .maybeSingle();

      final userId = userData != null ? userData['id'] : authUser.id;

      final response = await SupabaseService.client
          .from('orders')
          .select('*')
          .eq('id', orderId)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;

      Map<String, dynamic> orderData = Map<String, dynamic>.from(response);
      
      // If items are missing or empty in JSON column, try fetching from order_items table
      if (orderData['items'] == null || (orderData['items'] as List).isEmpty) {
        try {
          final itemsResponse = await SupabaseService.client
              .from('order_items')
              .select('*')
              .eq('order_id', orderId);
          
          if (itemsResponse.isNotEmpty) {
            orderData['items'] = itemsResponse;
          }
        } catch (e) {
          print('Note: Could not fetch from order_items table: $e');
        }
      }

      return OrderModel.fromJson(orderData);
        } catch (e) {
      throw Exception('Error fetching order: $e');
    }
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      final authUser = SupabaseService.instance.currentUser;
      if (authUser == null) {
        throw Exception('User not authenticated');
      }

      // Resolve public user ID
      final userData = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('email', authUser.email!)
          .maybeSingle();

      final userId = userData != null ? userData['id'] : authUser.id;

      // Update both status and order_status for compatibility
      await SupabaseService.client
          .from('orders')
          .update({
            'order_status': status,
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Error updating order status: $e');
    }
  }


  Future<void> cancelOrder(String orderId) async {
    try {
      await updateOrderStatus(orderId, 'cancelled');
    } catch (e) {
      throw Exception('Error cancelling order: $e');
    }
  }
}
