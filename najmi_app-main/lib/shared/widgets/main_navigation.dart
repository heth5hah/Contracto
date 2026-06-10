import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:contracto_app/features/auth/presentation/screens/blinkit_style_home.dart';
import 'package:contracto_app/features/cart/presentation/screens/cart_screen.dart';
import 'package:contracto_app/features/cart/data/services/cart_service.dart';
import 'package:contracto_app/features/orders/presentation/screens/orders_screen.dart';
import 'package:contracto_app/features/quotations/presentation/screens/quotations_screen.dart';
import 'package:contracto_app/core/network/supabase_service.dart';
import 'package:contracto_app/core/services/realtime_sync_service.dart';
import 'package:contracto_app/core/services/user_realtime_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';

class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;

  NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.color,
  });
}

class MainNavigation extends StatefulWidget {
  final int initialIndex;

  const MainNavigation({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with TickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _animationController;
  StreamSubscription? _notificationSubscription;
  StreamSubscription? _authSubscription;
  final AudioPlayer _audioPlayer = AudioPlayer();

  final GlobalKey<BlinkitStyleHomeState> _homeKey =
      GlobalKey<BlinkitStyleHomeState>();

  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Home',
      color: const Color(0xFF4F46E5),
    ),
    NavigationItem(
      icon: Icons.description_outlined,
      activeIcon: Icons.description,
      label: 'Quotes',
      color: const Color(0xFF8B5CF6),
    ),
    NavigationItem(
      icon: Icons.shopping_bag_outlined,
      activeIcon: Icons.shopping_bag,
      label: 'Cart',
      color: const Color(0xFFF59E0B),
    ),
    NavigationItem(
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long,
      label: 'Orders',
      color: const Color(0xFFEF4444),
    ),
  ];

  int _unreadNotificationCount = 0;
  /// Quote request ID to deep-link into after switching to the Quotes tab.
  String? _pendingQuoteId;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    // Initialize notification listener after first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenToAuthChanges();
      _initNotifications();
    });
  }

  void _listenToAuthChanges() {
    _authSubscription?.cancel();
    _authSubscription =
        SupabaseService.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        debugPrint(
            'Auth state changed: signedIn. Re-initializing notifications.');
        _initNotifications();
      } else if (data.event == AuthChangeEvent.signedOut) {
        debugPrint('Auth state changed: signedOut. Cancelling notifications.');
        _notificationSubscription?.cancel();
        _notificationSubscription = null;
        if (mounted) setState(() => _unreadNotificationCount = 0);
      }
    });
  }

  void _initNotifications() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId != null) {
      debugPrint('Initializing notifications for user ID: $userId');
      final realtimeSync = RealtimeSyncService();

      // Fetch initial unread count
      try {
        final count = await SupabaseService.client
            .from('notifications')
            .count(CountOption.exact)
            .eq('user_id', userId)
            .eq('is_read', false);
        if (mounted) setState(() => _unreadNotificationCount = count);
      } catch (e) {
        debugPrint('Error fetching unread notification count: $e');
      }

      // Subscribe to notifications
      await realtimeSync.subscribeToUserNotifications(userId);
       
      // Initialize user-specific real-time services (security, orders, etc.)
      await UserRealtimeService().initialize();

      // Cancel previous subscription if it exists
      await _notificationSubscription?.cancel();

      // Listen for notifications
      _notificationSubscription =
          realtimeSync.notificationStream.listen((notification) {
        debugPrint('Received notification from stream: $notification');
        if (mounted) {
          setState(() {
            _unreadNotificationCount++;
          });
          _playNotificationSound();
          _showNotificationDialog(notification);
        }
      });
    } else {
      debugPrint('Skipping notification initialization: No user logged in');
    }
  }

  Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/notification.wav'));
    } catch (e) {
      debugPrint('Error playing notification sound: $e');
    }
  }

  void _showNotificationDialog(Map<String, dynamic> notification) {
    String title = notification['title'] ?? '';
    final type = notification['type']?.toString().toLowerCase() ?? 'system';

    if (title.isEmpty) {
      switch (type) {
        case 'quotation':
          title = 'Quotation Update';
          break;
        case 'order':
          title = 'Order Update';
          break;
        case 'payment':
          title = 'Payment Received';
          break;
        default:
          title = 'New Notification';
      }
    }

    final message = notification['message']?.toString() ?? 'You have a new notification.';

    IconData icon;
    Color color;

    switch (type) {
      case 'quotation':
        icon = Icons.description_outlined;
        color = const Color(0xFF8B5CF6); // Purple
        break;
      case 'order':
        icon = Icons.shopping_bag_outlined;
        color = const Color(0xFF3B82F6); // Blue
        break;
      case 'enquiry':
        icon = Icons.support_agent;
        color = const Color(0xFFF59E0B); // Amber
        break;
      case 'refund':
        icon = Icons.currency_rupee;
        color = const Color(0xFF10B981); // Green
        break;
      default:
        icon = Icons.notifications_active_outlined;
        color = const Color(0xFF6B7280); // Gray
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // Mark as read logic could go here if we had notification ID
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        foregroundColor: const Color(0xFF6B7280),
                      ),
                      child: const Text('Dismiss'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Navigate to relevant screen
                        if (type == 'quotation') {
                          // Store the reference_id so QuotationsScreen can auto-open it
                          final refId = notification['reference_id']?.toString();
                          if (mounted) {
                            setState(() {
                              _pendingQuoteId = refId;
                            });
                          }
                          _onItemTapped(1); // Quotes tab
                        } else if (type == 'order' || type == 'refund') {
                          _onItemTapped(3); // Orders tab
                        } else {
                          // For inquiries or others, going to profile/home might be best
                          // Or we could check if we have an enquiry screen
                          _onItemTapped(0); // Home tab
                        }
                        // Reset local unread count - simplistic approach
                        // Ideally we should mark specific notifications as read in backend
                        if (mounted) {
                          setState(() {
                            if (_unreadNotificationCount > 0) {
                              _unreadNotificationCount--;
                            }
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      child: const Text('View Details'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _notificationSubscription?.cancel();
    _authSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
      _animationController.forward().then((_) {
        _animationController.reverse();
      });
    }
  }

  void _switchToTab(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  void _switchToTabWithQuote(int index, {String? quoteId}) {
    setState(() {
      _currentIndex = index;
      if (quoteId != null) _pendingQuoteId = quoteId;
    });
  }

  Widget _getCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return BlinkitStyleHome(
          key: _homeKey,
          onSwitchToTab: (tabIndex, {String? quoteId}) =>
              _switchToTabWithQuote(tabIndex, quoteId: quoteId),
        );
      case 1:
        // If we have a pending quote ID from a notification, pass it to the screen
        // and use a unique key to force a fresh widget build that will auto-open it.
        final quoteId = _pendingQuoteId;
        if (quoteId != null) {
          // Clear after consuming so subsequent tab switches don't re-open it
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _pendingQuoteId = null);
          });
          return QuotationsScreen(
            key: ValueKey('quotes_$quoteId'),
            onSwitchToHome: () => _switchToTab(0),
            initialQuoteId: quoteId,
          );
        }
        return QuotationsScreen(onSwitchToHome: () => _switchToTab(0));
      case 2:
        return CartScreen(onNavigateToHome: () => _switchToTab(0));
      case 3:
        return const OrdersScreen();
      default:
        return BlinkitStyleHome(key: _homeKey);
    }
  }

  Future<bool> _onWillPop() async {
    // specific logic for Home tab (index 0)
    if (_currentIndex == 0) {
      final handled = await _homeKey.currentState?.handleBack();
      if (handled == true) {
        return false;
      }
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Exit App'),
          content: const Text('Are you sure you want to exit the app?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Exit'),
            ),
          ],
        ),
      );
      return shouldExit ?? false;
    } else {
      _onItemTapped(0);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _onWillPop();
        if (shouldExit && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            _getCurrentScreen(),
            if (!isKeyboardVisible)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(34), // Perfect outer pill radius
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(34),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Container(
                        height: 68,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.65), // True frosted glass
                          borderRadius: BorderRadius.circular(34),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.8),
                            width: 1.5,
                          ),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final double totalWidth = constraints.maxWidth;
                            final int count = _navigationItems.length;
                            const double horizontalMargin = 7.0; // EXACT concentric margin (68-54=14 / 2)
                            final double innerWidth = totalWidth - (horizontalMargin * 2);
                            final double itemWidth = innerWidth / count;
                            
                            return Stack(
                              children: [
                                // Slider Highlight Pill
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                  top: 7,
                                  bottom: 7,
                                  left: horizontalMargin + (_currentIndex * itemWidth),
                                  width: itemWidth,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(27), // concentric 54 height match
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                        BoxShadow(
                                          color: Colors.white.withValues(alpha: 0.5),
                                          blurRadius: 10,
                                          offset: const Offset(0, -2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                
                                // Gesture Detector & Tap Zones
                                Positioned.fill(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onPanUpdate: (details) {
                                      final double dx = details.localPosition.dx - horizontalMargin;
                                      if (dx >= 0 && dx <= innerWidth) {
                                        final int newIndex = (dx / itemWidth).floor().clamp(0, count - 1);
                                        if (newIndex != _currentIndex) {
                                          HapticFeedback.selectionClick();
                                          _onItemTapped(newIndex);
                                        }
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: horizontalMargin),
                                      child: Row(
                                        children: List.generate(
                                          count,
                                          (index) => SizedBox(
                                            width: itemWidth,
                                            height: double.infinity,
                                            child: GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onTap: () {
                                                HapticFeedback.selectionClick();
                                                _onItemTapped(index);
                                              },
                                              child: _buildNavItemContent(index),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItemContent(int index) {
    final isSelected = _currentIndex == index;
    const Color activeHighlightColor = Color(0xFF4F46E5); // Indigo
    const Color inactiveContentColor = Color(0xFF94A3B8); // Slate 400

    final itemContentColor = isSelected ? activeHighlightColor : inactiveContentColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Icon
        AnimatedScale(
          scale: isSelected ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          child: _buildIcon(index, isSelected, itemContentColor),
        ),
        const SizedBox(height: 4),
        // Text
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: itemContentColor,
            height: 1.0,
          ),
          child: Text(
            _navigationItems[index].label,
            maxLines: 1,
            overflow: TextOverflow.visible,
          ),
        ),
      ],
    );
  }

  Widget _buildIcon(int index, bool isSelected, Color itemColor) {
    final icon = Icon(
      isSelected
          ? _navigationItems[index].activeIcon
          : _navigationItems[index].icon,
      color: itemColor,
      size: 24,
    );

    // Wrap cart icon with badge
    if (index == 2) {
      return AnimatedBuilder(
        animation: CartService(),
        builder: (context, child) {
          final count = CartService().cartItemCount;
          return Badge(
            isLabelVisible: count > 0,
            backgroundColor: const Color(0xFFEF4444),
            label: Text(
              '$count',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            child: child,
          );
        },
        child: icon,
      );
    }

    return icon;
  }
}
