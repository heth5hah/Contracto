import 'package:contracto_app/core/network/supabase_service.dart';
import 'package:contracto_app/features/products/data/models/enquiry_model.dart';

class EnquiryService {
  final _supabase = SupabaseService.client;

  /// Submit a new product enquiry
  Future<bool> submitEnquiry(EnquiryModel enquiry) async {
    try {
      await _supabase.from('enquiries').insert(enquiry.toCreateJson());
      return true;
    } catch (e) {
      print('Error submitting enquiry: $e');
      // Rethrow to show actual error to user
      rethrow;
    }
  }

  /// Get all enquiries for current user
  Future<List<EnquiryModel>> getUserEnquiries() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('enquiries')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => EnquiryModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching user enquiries: $e');
      return [];
    }
  }

  /// Get enquiry by ID
  Future<EnquiryModel?> getEnquiryById(String id) async {
    try {
      final response = await _supabase
          .from('enquiries')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;

      return EnquiryModel.fromJson(response);
    } catch (e) {
      print('Error fetching enquiry: $e');
      return null;
    }
  }

  /// Delete enquiry
  Future<bool> deleteEnquiry(String id) async {
    try {
      await _supabase.from('enquiries').delete().eq('id', id);
      return true;
    } catch (e) {
      print('Error deleting enquiry: $e');
      return false;
    }
  }
}
