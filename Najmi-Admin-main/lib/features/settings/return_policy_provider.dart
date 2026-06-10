import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';

/// Model for return policy settings
class ReturnPolicySettings {
  final bool returnsEnabled;
  final int returnWindowDays;

  const ReturnPolicySettings({
    this.returnsEnabled = true,
    this.returnWindowDays = 7,
  });

  factory ReturnPolicySettings.fromJson(Map<String, dynamic> json) {
    return ReturnPolicySettings(
      returnsEnabled: json['returns_enabled'] ?? true,
      returnWindowDays: json['return_window_days'] ?? 7,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'returns_enabled': returnsEnabled,
      'return_window_days': returnWindowDays,
    };
  }
}

/// Provider for return policy settings
final returnPolicyProvider = FutureProvider<ReturnPolicySettings>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  
  try {
    final response = await supabase
        .from('settings')
        .select('value')
        .eq('key', 'return_policy')
        .maybeSingle();

    if (response != null && response['value'] != null) {
      return ReturnPolicySettings.fromJson(response['value'] as Map<String, dynamic>);
    }
    return const ReturnPolicySettings();
  } catch (e) {
    print('Error fetching return policy: $e');
    return const ReturnPolicySettings();
  }
});

/// Service for managing return policy settings
final returnPolicyManagementProvider = Provider((ref) => ReturnPolicyManagementService(ref));

class ReturnPolicyManagementService {
  final Ref ref;
  
  ReturnPolicyManagementService(this.ref);

  Future<bool> saveSettings(ReturnPolicySettings settings) async {
    final supabase = ref.read(supabaseProvider);
    
    try {
      // Check if settings exist
      final existing = await supabase
          .from('settings')
          .select('id')
          .eq('key', 'return_policy')
          .maybeSingle();

      if (existing != null) {
        // Update existing
        await supabase
            .from('settings')
            .update({'value': settings.toJson()})
            .eq('key', 'return_policy');
      } else {
        // Insert new
        await supabase.from('settings').insert({
          'key': 'return_policy',
          'value': settings.toJson(),
          'description': 'Return policy configuration',
        });
      }

      // Invalidate provider to refresh data
      ref.invalidate(returnPolicyProvider);
      return true;
    } catch (e) {
      print('Error saving return policy settings: $e');
      return false;
    }
  }
}
