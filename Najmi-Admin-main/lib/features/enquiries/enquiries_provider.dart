import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../main.dart';

/// Simple model representing a requested product / enquiry coming
/// from the customer app (najmi_app-main).
class AdminEnquiry {
  final String id;
  final String userId;
  final String productName;
  final String? category;
  final String message;
  final String? contactEmail;
  final String? contactPhone;
  final String status; // pending, contacted, resolved, closed
  final DateTime createdAt;

  AdminEnquiry({
    required this.id,
    required this.userId,
    required this.productName,
    this.category,
    required this.message,
    this.contactEmail,
    this.contactPhone,
    required this.status,
    required this.createdAt,
  });

  factory AdminEnquiry.fromJson(Map<String, dynamic> json) {
    return AdminEnquiry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      productName: json['product_name'] as String,
      category: json['category'] as String?,
      message: json['message'] as String,
      contactEmail: json['contact_email'] as String?,
      contactPhone: json['contact_phone'] as String?,
      status: (json['status'] as String?) ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Provider that fetches all product enquiries (requested products)
/// for display in the admin dashboard.
final enquiriesProvider = FutureProvider<List<AdminEnquiry>>((ref) async {
  final SupabaseClient supabase = ref.watch(supabaseProvider);

  final response = await supabase
      .from('enquiries')
      .select()
      .order('created_at', ascending: false);

  final List data = response as List;
  return data
      .map((e) => AdminEnquiry.fromJson(e as Map<String, dynamic>))
      .toList();
});

Future<void> updateEnquiryStatus(WidgetRef ref, String id, String status) async {
  final supabase = ref.read(supabaseProvider);
  await supabase.from('enquiries').update({'status': status}).eq('id', id);
  ref.invalidate(enquiriesProvider);
}
