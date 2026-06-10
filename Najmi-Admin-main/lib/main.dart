import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/supabase/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'core/navigation/app_router.dart';
import 'core/services/admin_notification_service.dart';

// Top level provider for Supabase client
final supabaseProvider = Provider<SupabaseClient>((ref) => SupabaseConfig.client);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SupabaseConfig.init();

  // Initialize Admin Notification Service
  await AdminNotificationService().initialize(SupabaseConfig.client);
  debugPrint('Admin Notification Service initialized');

  runApp(
    const ProviderScope(
      child: ContractoAdminApp(),
    ),
  );
}

class ContractoAdminApp extends ConsumerWidget {
  const ContractoAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Contracto',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
