import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'main_layout.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/products/product_list_screen.dart';
import '../../features/products/product_form_screen.dart';
import '../../features/products/product_model.dart';
import '../../features/orders/order_list_screen.dart';
import '../../features/categories/categories_screen.dart';
import '../../features/brands/brands_screen.dart';
import '../../features/quotations/quotations_screen.dart';
import '../../features/users/users_screen.dart';
import '../../features/featured/featured_screen.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/auth/login_screen.dart';
import '../../features/pricing/coupon_management_screen.dart';
import '../../features/settings/tax_settings_screen.dart';
import '../../features/settings/return_policy_settings_screen.dart';
import '../../features/settings/unit_management_screen.dart';
import '../../features/returns/returns_management_screen.dart';
import '../../features/profile/admin_profile_screen.dart';
import '../../features/inventory/inventory_screen.dart';
import '../../features/ai_analytics/ai_analytics_screen.dart';
import '../../features/enquiries/enquiries_screen.dart';
import '../../features/discounts/discounts_screen.dart';
import '../../features/business_billing/business_billing_screen.dart';
final routerProvider = Provider<GoRouter>((ref) {
  // Create a ValueNotifier to listen to auth state changes
  final authStateListenable = ValueNotifier<AsyncValue<Session?>>(const AsyncValue.loading());
  
  // Update the notifier when auth state changes
  ref.listen<AsyncValue<Session?>>(
    authStateProvider,
    (_, next) => authStateListenable.value = next,
    fireImmediately: true,
  );

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authStateListenable,
    redirect: (context, state) {
      final session = authStateListenable.value.value;
      final isLoggingIn = state.uri.toString() == '/login';

      if (session == null && !isLoggingIn) {
        return '/login';
      }
      if (session != null && isLoggingIn) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainLayout(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/products',
            builder: (context, state) => const ProductListScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) {
                  final category = state.uri.queryParameters['category'];
                  return ProductFormScreen(initialCategory: category);
                },
              ),
              GoRoute(
                path: 'edit/:id',
                builder: (context, state) {
                  final productId = state.pathParameters['id'];
                  Product? product;
                  
                  if (state.extra is Product) {
                    product = state.extra as Product;
                  } else if (state.extra is Map<String, dynamic>) {
                    try {
                      product = Product.fromJson(state.extra as Map<String, dynamic>);
                    } catch (e) {
                      print('Error parsing product from extra: $e');
                    }
                  } else if (state.extra is Map) {
                     try {
                      product = Product.fromJson(Map<String, dynamic>.from(state.extra as Map));
                    } catch (e) {
                      print('Error parsing product from extra: $e');
                    }
                  }

                  return ProductFormScreen(
                    product: product,
                    productId: productId,
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/orders',
            builder: (context, state) => const OrderListScreen(),
          ),
          GoRoute(
            path: '/inventory',
            builder: (context, state) => const InventoryScreen(),
          ),
          GoRoute(
            path: '/categories',
            builder: (context, state) => const CategoriesScreen(),
          ),
          GoRoute(
            path: '/brands',
            builder: (context, state) => const BrandsScreen(),
          ),
          GoRoute(
            path: '/quotations',
            builder: (context, state) => const QuotationsScreen(),
          ),
          GoRoute(
            path: '/enquiries',
            builder: (context, state) => const EnquiriesScreen(),
          ),
          GoRoute(
            path: '/users',
            builder: (context, state) => const UsersScreen(),
          ),
          GoRoute(
            path: '/featured',
            builder: (context, state) => const FeaturedScreen(),
          ),
          GoRoute(
            path: '/coupons',
            builder: (context, state) => const CouponManagementScreen(),
          ),
          GoRoute(
            path: '/tax-settings',
            builder: (context, state) => const TaxSettingsScreen(),
          ),
          GoRoute(
            path: '/return-policy',
            builder: (context, state) => const ReturnPolicySettingsScreen(),
          ),
          GoRoute(
            path: '/returns',
            builder: (context, state) => const ReturnsManagementScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const AdminProfileScreen(),
          ),
          GoRoute(
            path: '/unit-management',
            builder: (context, state) => const UnitManagementScreen(),
          ),
          GoRoute(
            path: '/ai-analytics',
            builder: (context, state) => const AiAnalyticsScreen(),
          ),
          GoRoute(
            path: '/discounts',
            builder: (context, state) => const DiscountsScreen(),
          ),
          GoRoute(
            path: '/business-billing',
            builder: (context, state) => const BusinessBillingScreen(),
          ),
        ],
      ),
    ],
  );
});
