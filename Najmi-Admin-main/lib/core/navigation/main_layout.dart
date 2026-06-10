import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/notifications/presentation/widgets/notification_bell_widget.dart';

import '../../core/services/admin_badge_service.dart';
import '../../features/quotations/quotations_provider.dart';
import '../../features/orders/orders_provider.dart';

class MainLayout extends ConsumerStatefulWidget {
  final Widget child;
  const MainLayout({super.key, required this.child});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}



class _MainLayoutState extends ConsumerState<MainLayout> {

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final location = GoRouterState.of(context).uri.toString();

    return Scaffold(
      body: Row(
        children: [
          if (isDesktop) Sidebar(currentPath: location),
          Expanded(
            child: Column(
              children: [
                Header(title: _getTitle(location)),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isDesktop ? null : BottomNav(currentPath: location),
    );
  }

  String _getTitle(String path) {
    switch (path) {
      case '/': return 'Dashboard';
      case '/inventory': return 'Inventory';
      case '/ai-analytics': return 'AI Analytics';
      case '/products': return 'Products';
      case '/orders': return 'Orders';
      case '/returns': return 'Return Requests';
      case '/categories': return 'Categories';
      case '/brands': return 'Brands';
      case '/quotations': return 'Quotations';
      case '/enquiries': return 'Enquiries';
      case '/users': return 'Users';
      case '/business-billing': return 'Business Billing';
      case '/featured': return 'Featured';
      case '/coupons': return 'Coupons';
      case '/tax-settings': return 'Tax Settings';
      case '/return-policy': return 'Return Policy';
      case '/unit-management': return 'Unit Management';
      case '/discounts': return 'Discounts';
      default: return 'Contracto';
    }
  }
}

class Sidebar extends StatelessWidget {
  final String currentPath;
  const Sidebar({super.key, required this.currentPath});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: const Color(0xFF0F172A),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                const Icon(Icons.admin_panel_settings, color: Colors.blue, size: 32),
                const SizedBox(width: 12),
                const Text(
                  'Contracto',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _SidebarItem(icon: Icons.dashboard_outlined, label: 'Dashboard', path: '/', currentPath: currentPath),
                _SidebarItem(icon: Icons.shopping_bag_outlined, label: 'Products', path: '/products', currentPath: currentPath),
                _SidebarItem(icon: Icons.star_outline, label: 'Featured', path: '/featured', currentPath: currentPath),
                _SidebarItem(icon: Icons.shopping_cart_outlined, label: 'Orders', path: '/orders', currentPath: currentPath),
                _SidebarItem(icon: Icons.assignment_return_outlined, label: 'Returns', path: '/returns', currentPath: currentPath),
                _SidebarItem(icon: Icons.category_outlined, label: 'Categories', path: '/categories', currentPath: currentPath),
                _SidebarItem(icon: Icons.branding_watermark_outlined, label: 'Brands', path: '/brands', currentPath: currentPath),
                _SidebarItem(icon: Icons.request_quote_outlined, label: 'Quotations', path: '/quotations', currentPath: currentPath),
                _SidebarItem(icon: Icons.question_answer_outlined, label: 'Enquiries', path: '/enquiries', currentPath: currentPath),
                _SidebarItem(icon: Icons.people_outline, label: 'Users', path: '/users', currentPath: currentPath),
                _SidebarItem(icon: Icons.account_balance_wallet_outlined, label: 'Business Billing', path: '/business-billing', currentPath: currentPath),
                _SidebarItem(icon: Icons.inventory_2_outlined, label: 'Inventory', path: '/inventory', currentPath: currentPath),
                _SidebarItem(icon: Icons.auto_awesome_outlined, label: 'AI Analytics', path: '/ai-analytics', currentPath: currentPath),
                _SidebarItem(icon: Icons.local_offer_rounded, label: 'Discounts', path: '/discounts', currentPath: currentPath),
                const Divider(color: Colors.grey, height: 1),
                _SidebarItem(icon: Icons.local_offer_outlined, label: 'Coupons', path: '/coupons', currentPath: currentPath),
                _SidebarItem(icon: Icons.calculate_outlined, label: 'Tax Settings', path: '/tax-settings', currentPath: currentPath),
              _SidebarItem(icon: Icons.assignment_return_outlined, label: 'Return Policy', path: '/return-policy', currentPath: currentPath),
                _SidebarItem(icon: Icons.straighten_outlined, label: 'Unit Management', path: '/unit-management', currentPath: currentPath),
                const Divider(color: Colors.grey, height: 1),
                _SidebarItem(icon: Icons.person_outline, label: 'Profile', path: '/profile', currentPath: currentPath),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends ConsumerWidget {
  final IconData icon;
  final String label;
  final String path;
  final String currentPath;

  const _SidebarItem({required this.icon, required this.label, required this.path, required this.currentPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = currentPath == path;
    final badges = ref.watch(adminBadgesProvider);
    final count = badges[path] ?? 0;

    return ListTile(
      leading: Icon(icon, color: isActive ? Colors.blue : Colors.grey),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label, 
              style: TextStyle(color: isActive ? Colors.white : Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
      tileColor: isActive ? Colors.white.withOpacity(0.05) : null,
      onTap: () => context.go(path),
    );
  }
}

class Header extends ConsumerWidget {
  final String title;
  const Header({super.key, required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title, 
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Simple admin profile chip with avatar + name and menu
                  _AdminProfileMenu(),
                  const SizedBox(width: 8),
                  const NotificationBellWidget(),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => ref.read(authStateProvider.notifier).logout(),
                    icon: const Icon(Icons.logout),
                    color: Colors.red[400],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small profile chip shown in the main admin header.
/// For now it just shows "Admin" and lets you navigate to the /profile page
/// or logout from the popup menu.
class _AdminProfileMenu extends ConsumerWidget {
  const _AdminProfileMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Profile',
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (value) {
        switch (value) {
          case 'profile':
            context.go('/profile');
            break;
          case 'logout':
            ref.read(authStateProvider.notifier).logout();
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'profile',
          child: ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('Profile'),
          ),
        ),
        const PopupMenuItem(
          value: 'logout',
          child: ListTile(
            leading: Icon(Icons.logout, color: Colors.redAccent),
            title: Text('Logout'),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 14,
              backgroundColor: Color(0xFF0F172A),
              child: Icon(Icons.person, size: 16, color: Colors.white),
            ),
            if (MediaQuery.of(context).size.width > 600) ...[
              const SizedBox(width: 8),
              const Text(
                'Admin',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF64748B)),
            ]
          ],
        ),
      ),
    );
  }
}

class BottomNav extends StatelessWidget {
  final String currentPath;
  const BottomNav({super.key, required this.currentPath});

  @override
  Widget build(BuildContext context) {
    final currentIndex = _getIndex(currentPath);
    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      onTap: (index) => context.go(_getPath(index)),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dash'),
        BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: 'Prod'),
        BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Orders'),
        BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
      ],
    );
  }

  int _getIndex(String path) {
    if (path == '/') return 0;
    if (path == '/products') return 1;
    if (path == '/orders') return 2;
    return 3;
  }

  String _getPath(int index) {
    switch (index) {
      case 0: return '/';
      case 1: return '/products';
      case 2: return '/orders';
      default: return '/categories';
    }
  }
}
