import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/app_router.dart';
import 'src/theme/app_theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'src/features/auth/auth_provider.dart';
import 'src/features/notifications/notification_manager.dart';
import 'src/core/providers.dart';
import 'src/core/theme/theme_provider.dart' as custom_theme;
import 'src/core/theme/theme_service.dart';

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
    
    // Check auth status on startup - wait for it to complete before showing router
    final authNotifier = ref.read(authProvider.notifier);
    Future.microtask(() => authNotifier.checkAuthStatus());
    
    final router = ref.watch(routerProvider);
    final customThemeMode = ref.watch(custom_theme.themeModeProvider);
    final themeService = ref.watch(custom_theme.themeServiceProvider);
    
    return MaterialApp.router(
      title: 'GekyChat Desktop',
      debugShowCheckedModeBanner: false,
      theme: themeService.getThemeData(customThemeMode),
      darkTheme: themeService.getThemeData(customThemeMode),
      themeMode: customThemeMode.isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }
}
