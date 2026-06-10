import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../main.dart';
import 'quotations_provider.dart';
import 'quotation_model.dart';
import 'quotation_pdf_service.dart';


class QuotationsScreen extends ConsumerWidget {
  const QuotationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotationsAsync = ref.watch(filteredQuotationsProvider);
    final statusFilter = ref.watch(adminStatusFilterProvider);
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Quote Requests',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                DropdownButton<String?>(
                  value: statusFilter,
                  hint: const Text('Filter by Status'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All')),
                    DropdownMenuItem(value: 'new', child: Text('New')),
                    DropdownMenuItem(
                      value: 'processing',
                      child: Text('Processing'),
                    ),
                    DropdownMenuItem(value: 'closed', child: Text('Closed')),
                  ],
                  onChanged: (value) {
                    ref.read(adminStatusFilterProvider.notifier).state = value;
                  },
                ),
              ],
            ),
          ),
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: TextField(
              decoration: InputDecoration(
                hintText:
                    'Search by Quote ID, Customer Name, Email, or Status...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF667EEA),
                    width: 2,
                  ),
                ),
              ),
              onChanged: (value) {
                ref.read(quotationsSearchProvider.notifier).state = value;
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: quotationsAsync.when(
                  skipLoadingOnReload: true,
                  data: (quotations) {
                    final searchQuery = ref.watch(quotationsSearchProvider);
                    if (quotations.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              searchQuery.isEmpty
                                  ? Icons.request_quote_outlined
                                  : Icons.search_off,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              searchQuery.isEmpty
                                  ? 'No quote requests found'
                                  : 'No quotes match your search',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            if (searchQuery.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Try a different search term',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: MaterialStateProperty.all(
                                  Colors.transparent,
                                ),
                                dataRowColor: MaterialStateProperty.all(
                                  Colors.transparent,
                                ),
                                columnSpacing: 16,
                                horizontalMargin: 0,
                                dividerThickness: 1,
                                columns: const [
                                  DataColumn(
                                    label: Text(
                                      'Quote ID',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Product/Customer',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Items',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Status',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Admin Status',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Date',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Action',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                ],
                                rows: quotations.map((quote) {
                                  return DataRow(
                                    key: ValueKey('row_${quote.id}'),
                                    cells: [
                                      DataCell(
                                        Text(
                                          '#${quote.id.substring(0, 8)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF334155),
                                          ),
                                        ),
                                        onTap: () => _showItemsDialog(
                                          context,
                                          ref,
                                          quote,
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          quote.customerName ??
                                              'Unknown Product',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF334155),
                                          ),
                                        ),
                                        onTap: () => _showItemsDialog(
                                          context,
                                          ref,
                                          quote,
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            '${quote.items.fold(0.0, (sum, item) => sum + item.quantity)} Units',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF475569),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        onTap: () => _showItemsDialog(
                                          context,
                                          ref,
                                          quote,
                                        ),
                                      ),
                                      DataCell(
                                        _StatusBadge(status: quote.status),
                                      ),
                                      DataCell(
                                        _AdminStatusBadge(
                                          status: quote.adminStatus,
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          dateFormat
                                              .format(quote.createdAt)
                                              .replaceAll(
                                                '-',
                                                '\u2011',
                                              ), // Use non-breaking hyphen to prevent date wrap
                                          style: const TextStyle(
                                            color: Color(0xFF334155),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        PopupMenuButton<String>(
                                          tooltip: 'Actions',
                                          onSelected: (value) async {
                                            if (value == 'view') {
                                              _showItemsDialog(
                                                context,
                                                ref,
                                                quote,
                                              );
                                            } else if (value == 'edit') {
                                              _showEditDialog(
                                                context,
                                                ref,
                                                quote,
                                              );
                                            } else if (value == 'approve') {
                                              print(
                                                '========================================',
                                              );
                                              print(
                                                'PASSING QUOTATION: ${quote.id}',
                                              );
                                              print(
                                                'Quote userId: ${quote.userId}',
                                              );
                                              print(
                                                'Quote customerName: ${quote.customerName}',
                                              );
                                              print(
                                                '========================================',
                                              );

                                              await ref
                                                  .read(quoteManagementProvider)
                                                  .updateQuote(
                                                    quote.id,
                                                    status:
                                                        'quoted', // Setting to quoted as it's the admin passing it
                                                  );

                                              // After passing the quote, notify the user in the mobile app
                                              await ref
                                                  .read(quoteManagementProvider)
                                                  .notifyUserQuoteQuoted(quote);

                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Quote status updated to Quoted and notification sent to user',
                                                    ),
                                                    backgroundColor:
                                                        Colors.green,
                                                  ),
                                                );
                                              }
                                            } else if (value == 'reject') {
                                              await ref
                                                  .read(quoteManagementProvider)
                                                  .updateQuote(
                                                    quote.id,
                                                    status: 'rejected',
                                                  );
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Quote status updated to Rejected',
                                                    ),
                                                    backgroundColor:
                                                        Colors.orange,
                                                  ),
                                                );
                                              }
                                             } else if (value ==
                                                'verify_payment') {
                                              try {
                                                // 1. Fetch full quote request details
                                                final supabase = ref.read(
                                                  supabaseProvider,
                                                );
                                                // Fetch quote_request_items joined with products(photos) to get product images
                                                final fullQuote = await supabase
                                                    .from('quote_requests')
                                                    .select(
                                                      '*, quotes(*, quote_items(*)), users:user_id(*), quote_request_items(*,products(id,product_name,photos))',
                                                    )
                                                    .eq('id', quote.id)
                                                    .maybeSingle();

                                                if (fullQuote != null) {
                                                  final quotes =
                                                      fullQuote['quotes']
                                                          as List?;
                                                  final user =
                                                      fullQuote['users']
                                                          as Map<
                                                            String,
                                                            dynamic
                                                          >?;
                                                  final firstQuote =
                                                      (quotes != null &&
                                                          quotes.isNotEmpty)
                                                      ? quotes[0]
                                                            as Map<
                                                              String,
                                                              dynamic
                                                            >
                                                      : null;
                                                  final quoteItems =
                                                      firstQuote != null
                                                      ? (firstQuote['quote_items']
                                                                as List? ??
                                                            [])
                                                      : [];
                                                  final totalAmount =
                                                      (firstQuote?['total_amount'] ??
                                                              fullQuote['total_amount'] ??
                                                              0.0)
                                                          .toDouble();

                                                  // Use quote_request_items (with product photos) as the source of truth
                                                  final requestItems = (fullQuote['quote_request_items'] as List? ?? []);
                                                  // Fallback: JSONB 'items' column (legacy)
                                                  final originalItems = fullQuote['items'] as List? ?? [];

                                                  // Build a lookup map: product_id -> image_url from quote_request_items
                                                  String? _resolveImageUrl(Map<String, dynamic>? reqItem) {
                                                    if (reqItem == null) return null;
                                                    // Try direct image_url field first
                                                    final direct = reqItem['image_url'] as String?;
                                                    if (direct != null && direct.isNotEmpty) return direct;
                                                    // Try products.photos array
                                                    final productsData = reqItem['products'];
                                                    if (productsData is Map<String, dynamic>) {
                                                      final photos = productsData['photos'];
                                                      if (photos is List && photos.isNotEmpty) {
                                                        return photos.first?.toString();
                                                      }
                                                    }
                                                    return null;
                                                  }

                                                  // Build map of product_id -> request item for quick lookup
                                                  final Map<String, Map<String, dynamic>> reqItemsByProductId = {};
                                                  for (final ri in requestItems) {
                                                    final pid = ri['product_id']?.toString();
                                                    if (pid != null) reqItemsByProductId[pid] = ri as Map<String, dynamic>;
                                                  }

                                                  // Read is_returnable from the quote level (constant for all items in a quote)
                                                  final quoteIsReturnable = (firstQuote?['is_returnable'] as bool?) ?? true;

                                                  final orderItems = [];
                                                  for (int i = 0; i < quoteItems.length; i++) {
                                                    final item = quoteItems[i];

                                                    // 1. Match by product_id first (most reliable)
                                                    final itemProductId = item['quality_option_id']?.toString();
                                                    Map<String, dynamic>? matchedReqItem =
                                                        itemProductId != null ? reqItemsByProductId[itemProductId] : null;

                                                    // 2. Fall back to position-based match
                                                    matchedReqItem ??= (i < requestItems.length
                                                        ? requestItems[i] as Map<String, dynamic>
                                                        : null);

                                                    // 3. JSONB 'items' column (legacy)
                                                    final origItem = i < originalItems.length ? originalItems[i] : null;

                                                    // Resolve the best image URL available
                                                    final resolvedImage =
                                                        _resolveImageUrl(matchedReqItem) ??
                                                        origItem?['image_url'] as String? ??
                                                        item['product_image'] as String? ??
                                                        item['image_url'] as String?;

                                                   orderItems.add({
                                                      'product_id': matchedReqItem?['product_id'] ?? origItem?['product_id'] ?? item['quality_option_id'],
                                                      'product_name': matchedReqItem?['product_name'] ?? origItem?['product_name'] ?? item['quality_option_name'] ?? 'Quote Item',
                                                      'quantity': item['quantity'] ?? 1,
                                                      'unit_price': item['unit_price'] ?? 0.0,
                                                      'total_price': item['total_price'] ?? 0.0,
                                                      'unit': item['unit'] ?? 'units',
                                                      'image_url': resolvedImage,
                                                      'product_image': resolvedImage,
                                                      'brand_name': item['brand_name'] ?? matchedReqItem?['quality_option']?['name'],
                                                      'quality_option': matchedReqItem?['quality_option'],
                                                      'is_returnable': quoteIsReturnable,
                                                    });
                                                  }

                                                  // 2. Create order in orders table
                                                  await supabase.from('orders').insert({
                                                    'user_id':
                                                        fullQuote['user_id'],
                                                    'customer_name':
                                                        fullQuote['customer_name'] ??
                                                        user?['name'] ??
                                                        '',
                                                    'customer_email':
                                                        fullQuote['customer_email'] ??
                                                        user?['email'] ??
                                                        '',
                                                    'customer_phone':
                                                        fullQuote['customer_phone'] ??
                                                        user?['mobile'] ??
                                                        '',
                                                    'delivery_address':
                                                        fullQuote['delivery_address'] ??
                                                        'Address from Quote',
                                                    'payment_method':
                                                        fullQuote['payment_method'] == 'credit'
                                                            ? 'Credit Line (Quote)'
                                                            : 'Bank Transfer (Quote)',
                                                    'payment_source':
                                                        fullQuote['payment_method'] == 'credit'
                                                            ? 'credit'
                                                            : 'bank_transfer',
                                                    'transaction_id':
                                                        fullQuote['transaction_id'],
                                                    'payment_status': 'awaiting_confirmation',
                                                    'order_status': 'confirmed',
                                                    'total_amount': totalAmount,
                                                    'subtotal':
                                                        firstQuote?['subtotal'] ??
                                                        totalAmount,
                                                    'gst_amount':
                                                        firstQuote?['tax_amount'] ??
                                                        0,
                                                    'delivery_charge': 0,
                                                    'items': orderItems,
                                                    'notes':
                                                        'Created from Quote #${quote.id.substring(0, 8)} | Payment verified by admin',
                                                    'created_at': DateTime.now()
                                                        .toIso8601String(),
                                                  });
                                                }

                                                // 3. Mark quote as order_placed
                                                await ref
                                                    .read(
                                                      quoteManagementProvider,
                                                    )
                                                    .updateQuote(
                                                      quote.id,
                                                      status: 'order_placed',
                                                    );

                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Order verified, placed and moved to Orders section',
                                                      ),
                                                      backgroundColor:
                                                          Colors.purple,
                                                    ),
                                                  );
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Error placing order: $e',
                                                      ),
                                                      backgroundColor:
                                                          Colors.red,
                                                    ),
                                                  );
                                                }
                                              }
                                            } else if (value == 'download') {
                                              await _downloadPdf(
                                                context,
                                                quote.id,
                                              );
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            PopupMenuItem(
                                              value: 'view',
                                              child: _ActionMenuItem(
                                                icon: Icons.visibility_outlined,
                                                label: 'View Details',
                                                color: Colors.blue[700]!,
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'approve',
                                              child: _ActionMenuItem(
                                                icon:
                                                    Icons.check_circle_outline,
                                                label: 'Pass / Quoted',
                                                color: Colors.green[700]!,
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'reject',
                                              child: _ActionMenuItem(
                                                icon: Icons.highlight_off,
                                                label: 'Reject',
                                                color: Colors.red[700]!,
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'edit',
                                              child: _ActionMenuItem(
                                                icon: Icons.edit_outlined,
                                                label: 'Edit Pricing',
                                                color: Colors.blueGrey[700]!,
                                              ),
                                            ),
                                            if (quote.status ==
                                                    'payment_details_sent' ||
                                                quote.status ==
                                                    'quotation_accepted')
                                              PopupMenuItem(
                                                value: 'verify_payment',
                                                child: _ActionMenuItem(
                                                  icon: Icons
                                                      .verified_user_outlined,
                                                  label: 'Place Order',
                                                  color: Colors.purple[700]!,
                                                ),
                                              ),
                                            PopupMenuItem(
                                              value: 'download',
                                              child: _ActionMenuItem(
                                                icon: Icons
                                                    .file_download_outlined,
                                                label: 'Download PDF',
                                                color: Colors.indigo[700]!,
                                              ),
                                            ),
                                          ],
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: const Color(0xFFE2E8F0),
                                              ),
                                            ),
                                            child: Wrap(
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              children: const [
                                                Text(
                                                  'Actions',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF475569),
                                                  ),
                                                ),
                                                SizedBox(width: 4),
                                                Icon(
                                                  Icons.keyboard_arrow_down,
                                                  size: 16,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ), // DataTable
                            ), // SingleChildScrollView (horizontal)
                          ), // SingleChildScrollView (vertical)
                        ), // Expanded
                      ], // children
                    ); // Column
                  }, // data:
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text('Error: $err'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref.refresh(quotationsProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Quotation quote) {
    try {
      showDialog(
        context: context,
        useRootNavigator: true,
        builder: (context) => _EditQuoteDialog(quote: quote),
      );
    } catch (e) {
      debugPrint('Error showing edit dialog: $e');
    }
  }

  void _showItemsDialog(BuildContext context, WidgetRef ref, Quotation quote) {
    try {
      // If the quote is 'new', viewing it should mark it as 'processing' (viewed)
      // This clears the badge count for 'new' items.
      if (quote.adminStatus == 'new') {
        // Run update in background effectively
        ref
            .read(quoteManagementProvider)
            .updateQuote(quote.id, adminStatus: 'processing');
      }

      showDialog(
        context: context,
        useRootNavigator: true,
        builder: (context) => _ViewItemsDialog(quote: quote),
      );
    } catch (e) {
      debugPrint('Error showing details dialog: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error showing details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadPdf(BuildContext context, String quotationId) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await QuotationPdfService.downloadQuotationPdf(quotationId);

      if (context.mounted) {
        // Use rootNavigator: true to specifically target the dialog
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        // Use rootNavigator: true to specifically target the dialog
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'Details',
              textColor: Colors.white,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('PDF Error Details'),
                    content: SingleChildScrollView(child: Text(e.toString())),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String displayText;

    switch (status.toLowerCase()) {
      case 'pending':
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFF92400E);
        displayText = 'Pending';
        break;
      case 'quoted':
      case 'quotation_sent':
        bgColor = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF166534);
        displayText = 'Quoted';
        break;
      case 'quotation_accepted':
      case 'payment_details_sent':
        bgColor = const Color(0xFFFFF7ED);
        textColor = const Color(0xFFC2410C);
        displayText = 'Awaiting Verification';
        break;
      case 'order_placed':
        bgColor = const Color(0xFFD1FAE5);
        textColor = const Color(0xFF065F46);
        displayText = 'Order Placed';
        break;
      case 'accepted':
        bgColor = const Color(0xFFD1FAE5);
        textColor = const Color(0xFF065F46);
        displayText = 'Accepted';
        break;
      case 'rejected':
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFF991B1B);
        displayText = 'Rejected';
        break;
      case 'archived':
        bgColor = const Color(0xFFF3F4F6);
        textColor = const Color(0xFF374151);
        displayText = 'Archived';
        break;
      default:
        bgColor = const Color(0xFFE0E7FF);
        textColor = const Color(0xFF3730A3);
        displayText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AdminStatusBadge extends StatelessWidget {
  final String status;

  const _AdminStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String displayText;

    switch (status.toLowerCase()) {
      case 'new':
        bgColor = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF166534);
        displayText = 'New';
        break;
      case 'processing':
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFF92400E);
        displayText = 'Processing';
        break;
      case 'closed':
        bgColor = const Color(0xFFF3F4F6);
        textColor = const Color(0xFF374151);
        displayText = 'Closed';
        break;
      default:
        bgColor = const Color(0xFFF3F4F6);
        textColor = const Color(0xFF374151);
        displayText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EditQuoteDialog extends ConsumerStatefulWidget {
  final Quotation quote;

  const _EditQuoteDialog({required this.quote});

  @override
  ConsumerState<_EditQuoteDialog> createState() => _EditQuoteDialogState();
}

class _EditQuoteDialogState extends ConsumerState<_EditQuoteDialog> {
  late TextEditingController transportController;
  late TextEditingController validityDaysController;
  late List<TextEditingController> priceControllers;
  late List<bool> itemAvailability;
  late String selectedStatus;
  bool isReturnable = true; // admin-controlled returnability flag
  double subtotal = 0.0;
  double taxAmount = 0.0; // auto-computed from subtotal × taxPercent
  double grandTotal = 0.0;

  @override
  void initState() {
    super.initState();
    transportController = TextEditingController(
      text: widget.quote.transportCharges.toString(),
    );
    // Tax is now auto-calculated in _calculateTotals per item.
    validityDaysController = TextEditingController(
      text: widget.quote.validityDays.toString(),
    );

    // Initialise returnability from existing quote value
    isReturnable = widget.quote.isReturnable;

    // Create price controllers for each item
    priceControllers = widget.quote.items.map((item) {
      // Use existing price if available from quotedItems
      double initialPrice = 0.0;
      if (widget.quote.quotedItems != null) {
        final quotedItem = widget.quote.quotedItems!.firstWhere(
          (qi) => qi.qualityOptionName == item.qualityOptionName,
          orElse: () => item,
        );
        initialPrice = quotedItem.price;
      }
      return TextEditingController(text: initialPrice.toString());
    }).toList();

    // Initialize item availability from existing quotedItems
    itemAvailability = widget.quote.items.map((item) {
      bool initialAvailability = true;
      if (widget.quote.quotedItems != null) {
        final quotedItem = widget.quote.quotedItems!.firstWhere(
          (qi) => qi.qualityOptionName == item.qualityOptionName,
          orElse: () => item,
        );
        initialAvailability = quotedItem.isAvailable;
      }
      return initialAvailability;
    }).toList();

    selectedStatus = widget.quote.adminStatus;
    _calculateTotals();

    // Add listeners to recalculate on changes
    transportController.addListener(_calculateTotals);
    for (var controller in priceControllers) {
      controller.addListener(_calculateTotals);
    }
  }

  void _calculateTotals() {
    setState(() {
      subtotal = 0.0;
      taxAmount = 0.0;
      for (int i = 0; i < widget.quote.items.length; i++) {
        if (!itemAvailability[i]) continue;
        final item = widget.quote.items[i];
        final quantity = item.quantity;
        final unitPrice = double.tryParse(priceControllers[i].text) ?? 0.0;
        final itemTotal = quantity * unitPrice;

        subtotal += itemTotal;

        final itemGstPercent = item.gstPercent ?? 18.0;
        taxAmount += itemTotal * (itemGstPercent / 100);
      }
      final transport = double.tryParse(transportController.text) ?? 0.0;
      grandTotal = subtotal + transport + taxAmount;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.edit_outlined, color: Color(0xFF4F46E5)),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Edit Pricing - #${widget.quote.id.substring(0, 8)}'),
          ),
        ],
      ),
      content: SizedBox(
        width: 700,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer: ${widget.quote.customerName ?? "N/A"}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (widget.quote.customerEmail != null)
                      Text(
                        widget.quote.customerEmail!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Items Section
              const Text(
                'ITEM PRICING',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 12),

              // Items List
              ...List.generate(widget.quote.items.length, (index) {
                final item = widget.quote.items[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                if (item.brandName != null)
                                  Text(
                                    'Brand: ${item.brandName}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                if (item.qualityOptionName != null)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFF59E0B,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: const Color(
                                          0xFFF59E0B,
                                        ).withOpacity(0.3),
                                      ),
                                    ),
                                    child: Text(
                                      item.qualityOptionName!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFFF59E0B),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Qty: ${item.quantity.truncateToDouble() == item.quantity ? item.quantity.toInt() : item.quantity.toStringAsFixed(2)} ${item.unit ?? 'Units'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Switch(
                            value: itemAvailability[index],
                            activeColor: const Color(0xFF10B981),
                            onChanged: (val) {
                              setState(() {
                                itemAvailability[index] = val;
                              });
                              _calculateTotals();
                            },
                          ),
                          Text(
                            itemAvailability[index] ? 'Available' : 'Not Available',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: itemAvailability[index]
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: priceControllers[index],
                              enabled: itemAvailability[index],
                              decoration: InputDecoration(
                                labelText: itemAvailability[index] ? 'Unit Price (₹)' : 'Not Available',
                                border: const OutlineInputBorder(),
                                prefixText: '₹ ',
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: itemAvailability[index]
                                  ? const Color(0xFFF0FDF4)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: itemAvailability[index]
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Total',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: itemAvailability[index]
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  itemAvailability[index]
                                      ? '₹${((double.tryParse(priceControllers[index].text) ?? 0.0) * item.quantity).toStringAsFixed(2)}'
                                      : '₹0.00',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: itemAvailability[index]
                                        ? const Color(0xFF166534)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 24),

              // Transport Charges
              TextField(
                controller: transportController,
                decoration: const InputDecoration(
                  labelText: 'Transport Charges (₹)',
                  border: OutlineInputBorder(),
                  prefixText: '₹ ',
                ),
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 24),

              // Computed tax amount chip (auto-calculated per item)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Tax Amount (calculated per item GST)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${taxAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    if (subtotal > 0)
                      Text(
                        '~${((taxAmount / subtotal) * 100).toStringAsFixed(1)}% effective rate on ₹${subtotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.amber[700],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Delivery / Validity Days
              TextField(
                controller: validityDaysController,
                decoration: InputDecoration(
                  labelText: 'Delivery / Validity Days',
                  border: const OutlineInputBorder(),
                  suffixText: 'days',
                  helperText: 'Shown to the customer as "Valid for X days"',
                  prefixIcon: const Icon(Icons.local_shipping_outlined),
                  filled: true,
                  fillColor: const Color(0xFFF0F9FF),
                ),
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 24),

              // Admin Status
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Admin Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'new', child: Text('New')),
                  DropdownMenuItem(
                    value: 'processing',
                    child: Text('Processing'),
                  ),
                  DropdownMenuItem(value: 'closed', child: Text('Closed')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedStatus = value);
                  }
                },
              ),

              const SizedBox(height: 24),

              // Returnability Toggle
              Container(
                decoration: BoxDecoration(
                  color: isReturnable
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isReturnable
                        ? const Color(0xFF86EFAC)
                        : const Color(0xFFFCA5A5),
                  ),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  secondary: Icon(
                    isReturnable
                        ? Icons.assignment_return_outlined
                        : Icons.block_outlined,
                    color: isReturnable
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                  ),
                  title: Text(
                    isReturnable ? 'Returnable' : 'Non-Returnable',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isReturnable
                          ? const Color(0xFF166534)
                          : const Color(0xFF991B1B),
                    ),
                  ),
                  subtitle: Text(
                    isReturnable
                        ? 'Customer can request a return for these items.'
                        : 'Return option will be HIDDEN from customer\'s order.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isReturnable
                          ? const Color(0xFF15803D)
                          : const Color(0xFFB91C1C),
                    ),
                  ),
                  value: isReturnable,
                  activeColor: const Color(0xFF16A34A),
                  inactiveTrackColor: const Color(0xFFFCA5A5),
                  inactiveThumbColor: const Color(0xFFDC2626),
                  onChanged: (val) => setState(() => isReturnable = val),
                ),
              ),

              const SizedBox(height: 24),

              // Totals Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDCFCE7), width: 2),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Subtotal',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF15803D),
                          ),
                        ),
                        Text(
                          '₹${subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Transport Charges',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF15803D),
                          ),
                        ),
                        Text(
                          '₹${(double.tryParse(transportController.text) ?? 0.0).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tax',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF15803D),
                          ),
                        ),
                        Text(
                          '₹${taxAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, thickness: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'GRAND TOTAL',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF166534),
                          ),
                        ),
                        Text(
                          '₹${grandTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF166534),
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveChanges,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text('Save Quote'),
        ),
      ],
    );
  }

  Future<void> _saveChanges() async {
    // Prepare item prices
    final itemPrices = List.generate(widget.quote.items.length, (index) {
      final item = widget.quote.items[index];
      final unitPrice = double.tryParse(priceControllers[index].text) ?? 0.0;

      return {
        'quality_option_id':
            item.productId, // Use product_id if quality_option_id not available
        'quality_option_name': item.qualityOptionName ?? item.productName,
        'quantity': item.quantity,
        'unit': item.unit ?? 'units',
        'unit_price': unitPrice,
        'brand_id': item.brandId,
        'brand_name': item.brandName,
        'is_available': itemAvailability[index],
      };
    });

    final transportCharges = double.tryParse(transportController.text) ?? 0.0;
    final validityDays = int.tryParse(validityDaysController.text.trim()) ?? 7;

    try {
      await ref
          .read(quoteManagementProvider)
          .createOrUpdateQuote(
            widget.quote.id,
            itemPrices,
            transportCharges: transportCharges,
            taxAmount: taxAmount, // auto-computed from subtotal × taxPercent
            adminStatus: selectedStatus,
            validityDays: validityDays,
            isReturnable: isReturnable,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quote saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving quote: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    transportController.dispose();
    validityDaysController.dispose();
    for (var controller in priceControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}

class _ViewItemsDialog extends StatefulWidget {
  final Quotation quote;

  const _ViewItemsDialog({required this.quote});

  @override
  State<_ViewItemsDialog> createState() => _ViewItemsDialogState();
}

class _ViewItemsDialogState extends State<_ViewItemsDialog> {
  String? _receiptUrl;

  @override
  void initState() {
    super.initState();
    _loadReceipt();
  }

  Future<void> _loadReceipt() async {
    try {
      final supabase = Supabase.instance.client;
      final row = await supabase
          .from('quote_requests')
          .select('payment_receipt_url')
          .eq('id', widget.quote.id)
          .maybeSingle();
      if (mounted && row != null) {
        setState(() => _receiptUrl = row['payment_receipt_url'] as String?);
      }
    } catch (e) {
      debugPrint('Error loading receipt in admin: $e');
    }
  }

  Future<void> _openReceipt() async {
    if (_receiptUrl == null) return;
    final uri = Uri.parse(_receiptUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.quote.items;
    final quotedItems = widget.quote.quotedItems ?? [];
    final displayItems = quotedItems.isNotEmpty ? quotedItems : items;

    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: const BoxDecoration(
          color: Color(0xFF4F46E5),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.description_outlined,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Quote #${widget.quote.id.substring(0, 8).toUpperCase()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(Icons.person_outline, 'Customer Information'),
              const SizedBox(height: 12),
              _buildInfoSection([
                _buildModernInfoRow(
                  Icons.account_circle_outlined,
                  'Full Name',
                  widget.quote.customerName ?? 'N/A',
                ),
                const Divider(),
                _buildModernInfoRow(
                  Icons.email_outlined,
                  'Email Address',
                  widget.quote.customerEmail ?? 'N/A',
                ),
                const Divider(),
                _buildModernInfoRow(
                  Icons.phone_outlined,
                  'Phone Number',
                  widget.quote.customerPhone ?? 'N/A',
                ),
                const Divider(),
                _buildModernInfoRow(
                  Icons.location_on_outlined,
                  'Delivery Address',
                  widget.quote.deliveryAddress ?? 'N/A',
                ),
              ]),

              const SizedBox(height: 24),
              _buildSectionHeader(Icons.info_outline, 'Status & Payment'),
              const SizedBox(height: 12),
              _buildInfoSection([
                _buildModernInfoRow(
                  Icons.assignment_outlined,
                  'Quotation Status',
                  widget.quote.status.toUpperCase(),
                ),
                if (widget.quote.paymentMethod != null) ...[
                  const Divider(),
                  _buildModernInfoRow(
                    Icons.payment_outlined,
                    'Payment Method',
                    widget.quote.paymentMethod == 'credit'
                        ? 'Credit Line'
                        : widget.quote.paymentMethod == 'bank_transfer'
                            ? 'Bank Transfer'
                            : widget.quote.paymentMethod == 'wallet_plus_bank'
                                ? 'Wallet + Bank Transfer'
                                : widget.quote.paymentMethod == 'cash_on_delivery'
                                    ? 'Cash On Delivery'
                                    : widget.quote.paymentMethod!,
                  ),
                ],
                if (widget.quote.transactionId != null) ...[
                  const Divider(),
                  _buildModernInfoRow(
                    Icons.receipt_long_outlined,
                    'Transaction ID / UTR',
                    widget.quote.transactionId!,
                  ),
                ],
              ]),

              const SizedBox(height: 24),
              _buildSectionHeader(
                Icons.inventory_2_outlined,
                'Items (${displayItems.length})',
              ),
              const SizedBox(height: 12),
              ...displayItems.map((item) => _buildModernItemTile(item)).toList(),

              if (quotedItems.isNotEmpty || widget.quote.totalAmount > 0) ...[
                const SizedBox(height: 24),
                _buildSectionHeader(
                  Icons.payments_outlined,
                  'Pricing Breakdown',
                ),
                const SizedBox(height: 12),
                _buildInfoSection(
                  [
                    ...quotedItems
                        .map(
                          (item) => Column(
                            children: [
                              _buildPricingRow(item),
                              if (item != quotedItems.last)
                                const Divider(color: Color(0xFFDCFCE7)),
                            ],
                          ),
                        )
                        .toList(),
                    if (quotedItems.isNotEmpty) const Divider(thickness: 2),
                    _buildTotalRow('Transport Charges', widget.quote.transportCharges),
                    const SizedBox(height: 4),
                    _buildTotalRow('Tax Amount', widget.quote.taxAmount),
                    const SizedBox(height: 4),
                    _buildTotalRow(
                      'Grand Total',
                      widget.quote.totalAmount,
                      isBold: true,
                    ),
                  ],
                  bgColor: const Color(0xFFF0FDF4),
                  borderColor: const Color(0xFFDCFCE7),
                ),
              ],

              // ── Payment Receipt (if uploaded by user) ──────────────────
              if (_receiptUrl != null) ...[
                const SizedBox(height: 24),
                _buildSectionHeader(
                  Icons.receipt_long,
                  'Payment Receipt',
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt, color: Color(0xFF16A34A), size: 22),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Customer has uploaded a payment receipt.',
                          style: TextStyle(color: Color(0xFF166534), fontSize: 13),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _openReceipt,
                        icon: const Icon(Icons.open_in_new, size: 16, color: Color(0xFF16A34A)),
                        label: const Text('View',
                            style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],

              if (widget.quote.notes?.isNotEmpty ?? false) ...[
                const SizedBox(height: 24),
                _buildSectionHeader(Icons.note_alt_outlined, 'Notes'),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFEDD5)),
                  ),
                  child: Text(
                    widget.quote.notes!,
                    style: const TextStyle(color: Color(0xFF9A3412)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildInfoSection(
    List<Widget> children, {
    Color? bgColor,
    Color? borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor ?? const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? const Color(0xFFE2E8F0)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF4F46E5)),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildModernInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPricingRow(QuotationItem item) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.brandName != null
                    ? '${item.productName} (Brand: ${item.brandName})'
                    : item.productName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF166534),
                ),
              ),
              Text(
                '${item.quantity} ${item.unit ?? 'Units'} @ ₹${item.price.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF15803D)),
              ),
            ],
          ),
        ),
        Text(
          '₹${(item.quantity * item.price).toStringAsFixed(2)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF166534),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: isBold ? const Color(0xFF166534) : const Color(0xFF15803D),
            fontSize: isBold ? 16 : 14,
          ),
        ),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isBold ? const Color(0xFF166534) : const Color(0xFF15803D),
            fontSize: isBold ? 18 : 14,
          ),
        ),
      ],
    );
  }

  Widget _buildModernItemTile(QuotationItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Product Name and Quantity Badge
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF4F46E5).withOpacity(0.08),
                  const Color(0xFF7C3AED).withOpacity(0.04),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.inventory_2,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.brandName != null &&
                          item.brandName!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFF10B981).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified,
                                size: 12,
                                color: Color(0xFF10B981),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                item.brandName!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${item.quantity.truncateToDouble() == item.quantity ? item.quantity.toInt() : item.quantity.toStringAsFixed(2)} ${item.unit ?? 'Units'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Details Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Cards Row
                Row(
                  children: [
                    // Size/Specification Card
                    Expanded(
                      child: _buildDetailCard(
                        icon: Icons.straighten,
                        label: 'Size/Spec',
                        value: item.qualityOptionName ?? 'Standard',
                        color: const Color(0xFF3B82F6),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Quantity Card
                    Expanded(
                      child: _buildDetailCard(
                        icon: Icons.shopping_cart,
                        label: 'Quantity',
                        value: '${item.quantity}',
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Unit Card
                    Expanded(
                      child: _buildDetailCard(
                        icon: Icons.scale,
                        label: 'Unit',
                        value: item.unit ?? 'units',
                        color: const Color(0xFF8B5CF6),
                      ),
                    ),
                    if (item.price > 0) ...[
                      const SizedBox(width: 10),
                      // Price Card
                      Expanded(
                        child: _buildDetailCard(
                          icon: Icons.sell_outlined,
                          label: 'Price',
                          value: '₹${item.price.toStringAsFixed(2)}',
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ],
                ),

                if (item.price > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Total: ₹${(item.price * item.quantity).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ],

                // Description if available
                if (item.productDescription != null &&
                    item.productDescription!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.description_outlined,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.productDescription!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF475569),
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Notes if available
                if (item.notes != null && item.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF9C3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE047)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.note_alt,
                          size: 16,
                          color: Color(0xFFCA8A04),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.notes!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF854D0E),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ModernBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _ModernBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _InfoField extends StatelessWidget {
  final String label;
  final String value;

  const _InfoField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey[500],
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ActionMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ActionMenuItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}
