import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';

// Tax Configuration Model
class TaxConfig {
  final String id;
  final String configKey;
  final Map<String, dynamic> configValue;
  final bool isActive;

  TaxConfig({
    required this.id,
    required this.configKey,
    required this.configValue,
    this.isActive = true,
  });

  factory TaxConfig.fromJson(Map<String, dynamic> json) {
    return TaxConfig(
      id: json['id'],
      configKey: json['config_key'],
      configValue: json['config_value'] as Map<String, dynamic>,
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'config_key': configKey,
      'config_value': configValue,
      'is_active': isActive,
    };
  }
}

// Provider for tax configurations
final taxConfigProvider = FutureProvider<List<TaxConfig>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  
  try {
    final response = await supabase
        .from('tax_config')
        .select('*')
        .eq('is_active', true);
    
    return (response as List).map((json) => TaxConfig.fromJson(json)).toList();
  } catch (e) {
    print('Error fetching tax config: $e');
    return [];
  }
});

// Provider for GST rates specifically
final gstRatesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final configs = await ref.watch(taxConfigProvider.future);
  final gstConfig = configs.firstWhere(
    (c) => c.configKey == 'gst_rates',
    orElse: () => TaxConfig(
      id: '',
      configKey: 'gst_rates',
      configValue: {'default': 18, 'categories': {}},
    ),
  );
  return gstConfig.configValue;
});

// Provider for business tax rules
final businessTaxRulesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final configs = await ref.watch(taxConfigProvider.future);
  final rulesConfig = configs.firstWhere(
    (c) => c.configKey == 'business_tax_rules',
    orElse: () => TaxConfig(
      id: '',
      configKey: 'business_tax_rules',
      configValue: {
        'require_pan': false,
        'require_gst': false,
        'validate_pan_format': true,
        'validate_gst_format': true,
      },
    ),
  );
  return rulesConfig.configValue;
});

// Tax configuration management service
final taxConfigManagementProvider = Provider((ref) => TaxConfigManagementService(ref));

class TaxConfigManagementService {
  final Ref ref;
  
  TaxConfigManagementService(this.ref);
  
  // Update GST rates
  Future<void> updateGstRates(Map<String, dynamic> rates) async {
    final supabase = ref.read(supabaseProvider);
    
    await supabase
        .from('tax_config')
        .update({'config_value': rates})
        .eq('config_key', 'gst_rates');
    
    ref.invalidate(taxConfigProvider);
    ref.invalidate(gstRatesProvider);
  }
  
  // Update business tax rules
  Future<void> updateBusinessTaxRules(Map<String, dynamic> rules) async {
    final supabase = ref.read(supabaseProvider);
    
    await supabase
        .from('tax_config')
        .update({'config_value': rules})
        .eq('config_key', 'business_tax_rules');
    
    ref.invalidate(taxConfigProvider);
    ref.invalidate(businessTaxRulesProvider);
  }
  
  // Calculate GST for a product/category - FIXED: Changed return type to Future<double>
  Future<double> calculateGst(double amount, String? category) async {
    final rates = await ref.read(gstRatesProvider.future);
    
    double gstPercent = rates['default'] ?? 18;
    
    if (category != null && rates['categories'] != null) {
      final categoryRates = rates['categories'] as Map<String, dynamic>;
      gstPercent = categoryRates[category] ?? gstPercent;
    }
    
    return amount * (gstPercent / 100);
  }
  
  // Validate PAN format
  bool validatePanFormat(String pan) {
    // PAN format: AAAAA9999A
    final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
    return panRegex.hasMatch(pan);
  }
  
  // Validate GST format
  bool validateGstFormat(String gst) {
    // GST format: 99AAAAA9999A9Z9
    final gstRegex = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');
    return gstRegex.hasMatch(gst);
  }
}
