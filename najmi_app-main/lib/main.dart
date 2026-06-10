import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

// Core imports
import 'package:contracto_app/core/config/app_config.dart';
import 'package:contracto_app/core/theme/app_theme.dart';
import 'package:contracto_app/core/network/supabase_service.dart';
import 'package:contracto_app/core/services/realtime_sync_service.dart';
import 'package:contracto_app/core/services/cache_manager.dart';
import 'package:contracto_app/core/services/user_realtime_service.dart';

// Feature imports
import 'package:contracto_app/features/auth/presentation/screens/auth_gate.dart';
import 'package:contracto_app/features/cart/data/services/cart_service.dart';
import 'package:contracto_app/features/quotations/data/services/quote_request_cart_service.dart';

// Shared widgets
import 'package:contracto_app/shared/widgets/main_navigation.dart';

// import 'package:firebase_core/firebase_core.dart';
import 'package:contracto_app/core/services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // // Initialize Firebase (Required for FCM)
  // try {
  //   await Firebase.initializeApp(); 
  //   debugPrint('Firebase initialized');
  // } catch (e) {
  //   debugPrint('Failed to initialize Firebase: $e');
  // }

  // Initialize Supabase Service (this also initializes Supabase)
  await SupabaseService.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  debugPrint('Supabase initialized successfully');

  // Initialize Cache Manager
  await CacheManager().initialize();
  debugPrint('Cache Manager initialized');

  // Initialize Real-time Sync Service
  await RealtimeSyncService().initialize();
  debugPrint('Real-time Sync Service initialized');
  
  // Initialize Push Notifications
  try {
    await PushNotificationService.initialize();
    debugPrint('Push Notification Service initialized');
  } catch (e) {
    debugPrint('Failed to initialize Push Notifications: $e');
  }

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Notify the UserRealtimeService about lifecycle changes
    UserRealtimeService().setAppLifecycleState(state);
    debugPrint('📱 App lifecycle state changed: $state');
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartService()),
        ChangeNotifierProvider(create: (_) => QuoteRequestCartService()),
      ],
      child: MaterialApp(
        title: 'Contracto',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: const AuthGate(),
        onGenerateRoute: (settings) {
          if (settings.name == '/main') {
            final initialIndex = settings.arguments is int
                ? settings.arguments as int
                : 0;
            return MaterialPageRoute(
              builder: (_) => MainNavigation(initialIndex: initialIndex),
              settings: settings,
            );
          }
          return null;
        },
      ),
    );
  }
}
