import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'src/app_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'src/features/auth/auth_provider.dart';
import 'src/features/notifications/notification_manager.dart';
import 'src/core/providers.dart';
import 'src/core/theme/theme_provider.dart' as custom_theme;
import 'src/core/theme/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize window manager for system tray support
  await windowManager.ensureInitialized();
  
  // Configure window options
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 720),
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );
  
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  
  // Set up window close handler to minimize to tray instead of quitting
  windowManager.setPreventClose(true);
  
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

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WindowListener {
  static bool _notificationsInitialized = false;
  static bool _authChecked = false;

  @override
  void initState() {
    super.initState();
    
    // Set up window listener for close events
    windowManager.addListener(this);
    
    // Initialize notifications asynchronously (one-time only)
    if (!_notificationsInitialized) {
      _notificationsInitialized = true;
      Future.microtask(() async {
        try {
          final apiService = ref.read(apiServiceProvider);
          // WidgetRef extends Ref, so we can pass it directly
          final notificationManager = await NotificationManager.create(apiService, ref);
          await notificationManager.setup();
          debugPrint('✅ Notifications initialized');
        } catch (e) {
          debugPrint('⚠️ Failed to initialize notifications: $e');
          // Reset flag on error so we can retry
          _notificationsInitialized = false;
        }
      });
    }
    
    // Check auth status on startup (one-time only)
    if (!_authChecked) {
      _authChecked = true;
      Future.microtask(() => ref.read(authProvider.notifier).checkAuthStatus());
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Future<void> onWindowClose() async {
    // Minimize to tray instead of closing
    await windowManager.hide();
  }

  @override
  Widget build(BuildContext context) {
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
