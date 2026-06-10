import 'package:flutter_test/flutter_test.dart';
import 'package:contracto_app/core/network/supabase_service.dart';
import 'package:contracto_app/core/config/app_config.dart';

void main() {
  test('check returns data', () async {
    await SupabaseService.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
    
    final res = await SupabaseService.client
        .from('returns')
        .select('id, order_id, user_id, return_status, orders(total_amount)')
        .eq('return_status', 'refund_completed');
        
    print('RETURNS: $res');
  });
}
