import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'users_provider.dart';
import 'user_model.dart';
import 'user_details_screen.dart';
import 'package:najmi_admin/main.dart';
import 'package:najmi_admin/core/widgets/action_menu_item.dart';

// State provider for filtering tabs
final userTypeFilterProvider = StateProvider<String?>((ref) => null);

// Provider for search query
final userSearchQueryProvider = StateProvider<String>((ref) => '');

// Provider for updating user status
final updateUserStatusProvider = FutureProvider.family<bool, Map<String, dynamic>>((ref, params) async {
  final supabase = ref.watch(supabaseProvider);
  try {
    await supabase
        .from('users')
        .update({'status': params['status']})
        .eq('id', params['user_id']);
    ref.invalidate(usersProvider);
    return true;
  } catch (e) {
    print('Error updating user status: $e');
    return false;
  }
});// Provider for activating credit account
final activateCreditProvider = FutureProvider.family<bool, Map<String, dynamic>>((ref, params) async {
  final supabase = ref.watch(supabaseProvider);
  try {
    await supabase
        .from('business_credit_accounts')
        .update({'status': params['status']})
        .eq('user_id', params['user_id']);
    ref.invalidate(usersProvider);
    return true;
  } catch (e) {
    print('Error activating credit: $e');
    return false;
  }
});

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      final usersAsync = ref.watch(usersProvider);
      final selectedFilter = ref.watch(userTypeFilterProvider);

      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: usersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) {
            print('UsersScreen Error: $err');
            print('Stack trace: $stack');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text(
                        'Error loading users',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        err.toString(),
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(usersProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          data: (allUsers) {
            print('UsersScreen: Received ${allUsers.length} users');
            
            if (allUsers.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No users found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Users will appear here once they register',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(usersProvider),
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                ),
              );
            }

            // --- Filter Logic ---
            final searchQuery = ref.watch(userSearchQueryProvider).toLowerCase();

            final businessUsers = allUsers
                .where((u) => u.isBusiness)
                .toList();
            final individualUsers = allUsers
                .where((u) => !u.isBusiness)
                .toList();

            var filteredUsers = selectedFilter == null
                ? allUsers
                : selectedFilter == 'business'
                    ? businessUsers
                    : individualUsers;

            if (searchQuery.isNotEmpty) {
              filteredUsers = filteredUsers.where((u) {
                final name = (u.name ?? '').toLowerCase();
                final email = u.email.toLowerCase();
                final company = (u.companyName ?? '').toLowerCase();
                final gst = (u.gstNumber ?? '').toLowerCase();
                return name.contains(searchQuery) ||
                    email.contains(searchQuery) ||
                    company.contains(searchQuery) ||
                    gst.contains(searchQuery);
              }).toList();
            }

            return ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                // --- Header ---
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Manage business and individual customers'),
                  ],
                ),
                const SizedBox(height: 24),

                // --- Tabs and Search ---
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _FilterTab(
                            label: 'All Users',
                            count: allUsers.length,
                            isSelected: selectedFilter == null,
                            onTap: () =>
                                ref.read(userTypeFilterProvider.notifier).state =
                                    null,
                          ),
                          const SizedBox(width: 12),
                          _FilterTab(
                            label: 'Business',
                            count: businessUsers.length,
                            icon: Icons.business,
                            isSelected: selectedFilter == 'business',
                            onTap: () => ref
                                .read(userTypeFilterProvider.notifier)
                                .state = 'business',
                          ),
                          const SizedBox(width: 12),
                          _FilterTab(
                            label: 'Individual',
                            count: individualUsers.length,
                            icon: Icons.person_outline,
                            isSelected: selectedFilter == 'individual',
                            onTap: () => ref
                                .read(userTypeFilterProvider.notifier)
                                .state = 'individual',
                          ),
                        ],
                      ),
                    ),
                    // Search Bar
                    Container(
                      constraints: const BoxConstraints(maxWidth: 300),
                      width: double.infinity,
                      height: 40,
                      child: TextField(
                        onChanged: (value) {
                          ref.read(userSearchQueryProvider.notifier).state = value;
                        },
                        decoration: InputDecoration(
                          hintText: 'Search Name, Email, or Company...',
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // --- Users List ---
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Table Header
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey[200]!),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              flex: 3,
                              child: Text('Customer',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            const Expanded(
                              flex: 2,
                              child: Text('Contact',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            const Expanded(
                              flex: 1,
                              child: Text('Type',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            const Expanded(
                              flex: 1,
                              child: Text('Orders',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            const Expanded(
                              flex: 1,
                              child: Text('Total',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            const Expanded(
                              flex: 2,
                              child: Text('Credit',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            const Expanded(
                              flex: 2,
                              child: Text('Actions',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                      // Table Rows
                      ...filteredUsers.asMap().entries.map((entry) {
                        final user = entry.value;
                        final isBusiness = user.isBusiness;
                        final userName = user.name ?? user.email.split('@')[0];
                        final userInitial =
                            userName.isNotEmpty ? userName[0].toUpperCase() : 'U';
                        final globalIndex = allUsers.indexOf(user);
                        final customerId = 'C${(globalIndex + 1).toString().padLeft(3, '0')}';

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[100]!),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Customer
                              Expanded(
                                flex: 3,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: isBusiness
                                          ? const Color(0xFFF3E8FF)
                                          : const Color(0xFFE0E7FF),
                                      child: isBusiness
                                          ? const Icon(
                                              Icons.business,
                                              size: 20,
                                              color: Color(0xFF7C3AED),
                                            )
                                          : Text(
                                              userInitial,
                                              style: TextStyle(
                                                  color: const Color(0xFF4F46E5),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14),
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            userName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color: Color(0xFF1F2937)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (isBusiness && user.companyName != null && user.companyName!.isNotEmpty)
                                            Text(
                                              user.companyName!,
                                              style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          if (isBusiness && user.gstNumber != null && user.gstNumber!.isNotEmpty)
                                            Text(
                                              'GST: ${user.gstNumber}',
                                              style: const TextStyle(
                                                  color: Color(0xFF4F46E5),
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 11),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          Text(
                                            '($customerId)',
                                            style: TextStyle(
                                                color: Colors.grey[500],
                                                fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Contact
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.email,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF374151)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (user.phone != null &&
                                        user.phone!.isNotEmpty)
                                      Text(
                                        user.phone!,
                                        style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12),
                                      ),
                                  ],
                                ),
                              ),
                              // Type
                              Expanded(
                                flex: 1,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isBusiness
                                        ? const Color(0xFFF3E8FF)
                                        : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isBusiness
                                            ? Icons.business
                                            : Icons.person_outline,
                                        size: 14,
                                        color: isBusiness
                                            ? Colors.purple
                                            : Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          isBusiness ? 'Business' : 'Individual',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: isBusiness
                                                ? Colors.purple
                                                : Colors.grey[800],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Orders
                              Expanded(
                                flex: 1,
                                child: Text('${user.ordersCount}'),
                              ),
                              // Total Spent
                              Expanded(
                                flex: 1,
                                child: Text(
                                  NumberFormat.currency(
                                    symbol: 'Rs ',
                                    decimalDigits: 0,
                                  ).format(user.totalSpent),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ),
                              // Credit (Business users only)
                              Expanded(
                                flex: 2,
                                child: isBusiness
                                    ? _buildCreditCell(context, ref, user)
                                    : const SizedBox(),
                              ),
                              // Actions
                              Expanded(
                                flex: 2,
                                child: PopupMenuButton<String>(
                                  tooltip: 'Actions',
                                  onSelected: (value) async {
                                    if (value == 'view') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              UserDetailsScreen(user: user),
                                        ),
                                      );
                                    } else if (value == 'toggle_block') {
                                      final newStatus = user.status == 'blocked'
                                          ? 'active'
                                          : 'blocked';
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text(newStatus == 'blocked'
                                              ? 'Block User'
                                              : 'Unblock User'),
                                          content: Text(
                                              'Are you sure you want to ${newStatus == 'blocked' ? 'block' : 'unblock'} this user?'),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context, false),
                                                child: const Text('Cancel')),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      newStatus == 'blocked'
                                                          ? Colors.orange
                                                          : Colors.green),
                                              child: Text(
                                                  newStatus == 'blocked'
                                                      ? 'Block'
                                                      : 'Unblock',
                                                  style: const TextStyle(
                                                      color: Colors.white)),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await ref.read(
                                            updateUserStatusProvider({
                                          'user_id': user.id,
                                          'status': newStatus
                                        }).future);
                                      }
                                    } else if (value == 'delete') {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Delete User'),
                                          content: const Text(
                                              'Are you sure you want to delete this user? This action cannot be undone.'),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context, false),
                                                child: const Text('Cancel')),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red),
                                              child: const Text('Delete',
                                                  style: TextStyle(
                                                      color: Colors.white)),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await ref.read(
                                            deleteUserProvider(user.id).future);
                                      }
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'view',
                                      child: ActionMenuItem(
                                        icon: Icons.remove_red_eye_outlined,
                                        label: 'View History',
                                        color: Color(0xFF0369A1),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'toggle_block',
                                      child: ActionMenuItem(
                                        icon: user.status == 'blocked'
                                            ? Icons.check_circle_outline
                                            : Icons.block_outlined,
                                        label: user.status == 'blocked'
                                            ? 'Unblock User'
                                            : 'Block User',
                                        color: user.status == 'blocked'
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: ActionMenuItem(
                                        icon: Icons.delete_outline,
                                        label: 'Delete User',
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                  child: const ActionMenuTrigger(),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),




              ],
            );
          },
        ),
      );
    } catch (e, stackTrace) {
      print('UsersScreen build error: $e');
      print('Stack trace: $stackTrace');
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Error rendering users screen',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  e.toString(),
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildCreditCell(BuildContext context, WidgetRef ref, AdminUser user) {
    if (user.creditLimit == null) {
      return ElevatedButton.icon(
        onPressed: () => _showEditCreditDialog(context, ref, user),
        icon: const Icon(Icons.add_moderator, size: 14),
        label: const Text('Activate Credit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981), // Emerald/Success color
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: const Size(0, 32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      );
    }

    final bool isActive = user.creditAccountStatus == 'active';
    final bool isPending = user.creditAccountStatus == 'pending';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Limit: ₹${NumberFormat('#,##,###').format(user.creditLimit)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  Text(
                    'Avail: ₹${NumberFormat('#,##,###').format(user.availableCredit ?? 0)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
              onPressed: () => _showEditCreditDialog(context, ref, user),
              tooltip: 'Edit Credit',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () async {
            if (isPending) {
              // Quick-activate: set to active with current limit
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Approve Credit'),
                  content: Text(
                    'Approve business credit for ${user.name ?? user.email}?\n\n'
                    'Current limit: ₹${NumberFormat('#,##,###').format(user.creditLimit)}\n'
                    'This will activate their credit line.',
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text('Approve', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(activateCreditProvider({'user_id': user.id, 'status': 'active'}).future);
              }
            } else {
              final newStatus = isActive ? 'inactive' : 'active';
              await ref.read(activateCreditProvider({'user_id': user.id, 'status': newStatus}).future);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isPending
                  ? Colors.amber.withOpacity(0.1)
                  : isActive
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isPending
                    ? Colors.amber.withOpacity(0.3)
                    : isActive
                        ? Colors.green.withOpacity(0.2)
                        : Colors.orange.withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPending
                      ? Icons.hourglass_top
                      : isActive
                          ? Icons.check_circle
                          : Icons.pause_circle_filled,
                  size: 10,
                  color: isPending
                      ? Colors.amber[800]
                      : isActive
                          ? Colors.green
                          : Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  isPending ? 'PENDING' : isActive ? 'ACTIVE' : 'INACTIVE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isPending
                        ? Colors.amber[800]
                        : isActive
                            ? Colors.green
                            : Colors.orange,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showEditCreditDialog(BuildContext context, WidgetRef ref, AdminUser user) {
    final creditLimitController = TextEditingController(
      text: user.creditLimit?.toStringAsFixed(0) ?? '0',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Credit - ${user.name}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.companyName ?? user.email,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 16),
              if (user.creditLimit != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Current Limit:'),
                          Text(
                            '₹${NumberFormat('#,##,###').format(user.creditLimit)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Available:'),
                          Text(
                            '₹${NumberFormat('#,##,###').format(user.availableCredit ?? 0)}',
                            style: TextStyle(color: Colors.green[700]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Used:'),
                          Text(
                            '₹${NumberFormat('#,##,###').format(user.usedCredit ?? 0)}',
                            style: TextStyle(color: Colors.orange[700]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: creditLimitController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'New Credit Limit',
                  hintText: 'Enter amount (e.g., 50000)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This will update the credit limit for this business user.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newLimit = double.tryParse(creditLimitController.text);
              if (newLimit == null || newLimit < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount')),
                );
                return;
              }

              try {
                final supabase = ref.read(supabaseProvider);
                
                // Check if credit account exists
                final existing = await supabase
                    .from('business_credit_accounts')
                    .select('id')
                    .eq('user_id', user.id)
                    .maybeSingle();

                if (existing == null) {
                  // Create new credit account
                  await supabase.from('business_credit_accounts').insert({
                    'user_id': user.id,
                    'credit_limit': newLimit,
                    'available_credit': newLimit,
                    'used_credit': 0,
                    'kyc_status': 'approved',
                    'status': 'active',
                  });
                } else {
                  // Update existing — also activate it (in case it's pending)
                  final currentUsed = user.usedCredit ?? 0;
                  final newAvailable = newLimit - currentUsed;
                  
                  await supabase
                      .from('business_credit_accounts')
                      .update({
                        'credit_limit': newLimit,
                        'available_credit': newAvailable,
                        'status': 'active',
                        'kyc_status': 'approved',
                      })
                      .eq('user_id', user.id);
                }

                // Refresh users list
                ref.invalidate(usersProvider);
                
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Credit limit updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final int count;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterTab({
    required this.label,
    required this.count,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: isSelected
              ? Border.all(color: Colors.grey[300]!)
              : Border.all(color: Colors.transparent),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.black87 : Colors.grey[600],
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.black87 : Colors.grey[600],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '($count)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

