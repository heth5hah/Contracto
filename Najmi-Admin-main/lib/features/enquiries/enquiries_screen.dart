import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'enquiries_provider.dart';

class EnquiriesScreen extends ConsumerWidget {
  const EnquiriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enquiriesAsync = ref.watch(enquiriesProvider);
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: const Text(
              'Product Enquiries',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
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
                child: enquiriesAsync.when(
                  skipLoadingOnReload: true,
                  data: (enquiries) {
                    if (enquiries.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.question_answer_outlined,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No enquiries found',
                              style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
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
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: MediaQuery.of(context).size.width - 48,
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
                                  dataRowMaxHeight: 80,
                                  dataRowMinHeight: 60,
                                  columns: const [
                                    DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Product & Category', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Contact Info', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Message', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                  rows: enquiries.map((enq) {
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(dateFormat.format(enq.createdAt))),
                                        DataCell(
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(enq.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                              if (enq.category != null && enq.category!.isNotEmpty)
                                                Text(enq.category!, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                        DataCell(
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              if (enq.contactEmail != null && enq.contactEmail!.isNotEmpty)
                                                Text(enq.contactEmail!),
                                              if (enq.contactPhone != null && enq.contactPhone!.isNotEmpty)
                                                Text(enq.contactPhone!, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 250,
                                            child: Text(
                                              enq.message,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        DataCell(_StatusBadge(status: enq.status)),
                                        DataCell(
                                          DropdownButton<String>(
                                            value: enq.status,
                                            underline: const SizedBox(),
                                            icon: const Icon(Icons.arrow_drop_down),
                                            items: const [
                                              DropdownMenuItem(value: 'pending', child: Text('Pending')),
                                              DropdownMenuItem(value: 'contacted', child: Text('Contacted')),
                                              DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                                              DropdownMenuItem(value: 'closed', child: Text('Closed')),
                                            ],
                                            onChanged: (newStatus) {
                                              if (newStatus != null && newStatus != enq.status) {
                                                updateEnquiryStatus(ref, enq.id, newStatus).then((_) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Status updated successfully')),
                                                    );
                                                  }
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(
                    child: Text('Error loading enquiries: $err', style: const TextStyle(color: Colors.red)),
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
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status.toLowerCase()) {
      case 'pending':
        bgColor = Colors.orange[100]!;
        textColor = Colors.orange[800]!;
        label = 'Pending';
        break;
      case 'contacted':
        bgColor = Colors.blue[100]!;
        textColor = Colors.blue[800]!;
        label = 'Contacted';
        break;
      case 'resolved':
      case 'closed':
        bgColor = Colors.green[100]!;
        textColor = Colors.green[800]!;
        label = status.substring(0, 1).toUpperCase() + status.substring(1).toLowerCase();
        break;
      default:
        bgColor = Colors.grey[200]!;
        textColor = Colors.grey[800]!;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
