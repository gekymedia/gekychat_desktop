import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/app_router.dart';
import 'src/theme/app_theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'src/features/auth/auth_provider.dart';
import 'src/features/notifications/notification_manager.dart';
import 'src/core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    debugPrint('Warning: Could not load .env file');
  }

  // Initialize notifications (will be done after ProviderScope is available)
  // Moved to a ProviderObserver or initialized in MyApp

  runApp(
    ProviderScope(
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize notifications asynchronously (one-time)
    Future.microtask(() async {
      try {
        final apiService = ref.read(apiServiceProvider);
        final notificationManager = await NotificationManager.create(apiService);
        await notificationManager.setup();
        debugPrint('✅ Notifications initialized');
      } catch (e) {
        debugPrint('⚠️ Failed to initialize notifications: $e');
      }
    });
    
    // Check auth status on startup
    ref.read(authProvider.notifier).checkAuthStatus();
    
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);
    
    return MaterialApp.router(
      title: 'GekyChat Desktop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
