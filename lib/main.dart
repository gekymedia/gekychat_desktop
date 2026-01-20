import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:system_tray/system_tray.dart';
import 'src/app_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'src/features/auth/auth_provider.dart';
import 'src/features/notifications/notification_manager.dart';
import 'src/core/providers.dart';
import 'src/core/services/taskbar_badge_service.dart';
import 'src/core/services/deep_link_service.dart';
import 'src/core/theme/theme_provider.dart' as custom_theme;

Future<void> main(List<String> args) async {
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

  // Initialize deep link service with command line arguments
  final deepLinkService = DeepLinkService();
  await deepLinkService.initialize(args: args);

  // Initialize notifications (will be done after ProviderScope is available)
  // Moved to a ProviderObserver or initialized in MyApp

  runApp(
    ProviderScope(
      child: MyApp(deepLinkService: deepLinkService),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  final DeepLinkService deepLinkService;
  
  const MyApp({super.key, required this.deepLinkService});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WindowListener {
  static bool _notificationsInitialized = false;
  static bool _authChecked = false;
  static SystemTray? _systemTray;

  @override
  void initState() {
    super.initState();
    
    // Set up window listener for close events
    windowManager.addListener(this);
    
    // Initialize system tray
    _initializeSystemTray();
    
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
    
    // Initialize taskbar badge service and update badge periodically
    _initializeBadgeService();
    
    // Set up deep link handler
    widget.deepLinkService.setLinkHandler((link) {
      _handleDeepLink(link);
    });
  }
  
  void _handleDeepLink(String link) {
    final parsed = widget.deepLinkService.parseLink(link);
    if (parsed != null && mounted) {
      final route = parsed['route'];
      if (route != null) {
        final router = ref.read(routerProvider);
        // Navigate to the route
        router.go(route);
        // If there's a conversation/group/channel ID, we might need to handle it
        // in the specific screen
        debugPrint('🔗 Navigated to: $route');
      }
    }
  }
  
  void _initializeBadgeService() {
    // Update badge immediately
    Future.microtask(() async {
      try {
        final badgeService = ref.read(taskbarBadgeServiceProvider);
        await badgeService.updateBadge();
      } catch (e) {
        debugPrint('Failed to initialize badge service: $e');
      }
    });
    
    // Update badge every 30 seconds
    Future.microtask(() async {
      while (mounted) {
        await Future.delayed(const Duration(seconds: 30));
        if (mounted) {
          try {
            final badgeService = ref.read(taskbarBadgeServiceProvider);
            await badgeService.updateBadge();
          } catch (e) {
            debugPrint('Failed to update badge: $e');
          }
        }
      }
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _initializeSystemTray() async {
    try {
      _systemTray = SystemTray();
      
      // Initialize system tray menu
      final menu = Menu();
      
      // Add "Show" menu item
      await menu.buildFrom([
        MenuItemLabel(
          label: 'Show GekyChat',
          onClicked: (menuItem) async {
            await windowManager.show();
            await windowManager.focus();
          },
        ),
        MenuItemLabel(
          label: 'Quit',
          onClicked: (menuItem) async {
            await windowManager.destroy();
          },
        ),
      ]);
      
      // Set menu
      await _systemTray!.setContextMenu(menu);
      
      // Set tooltip
      await _systemTray!.setToolTip('GekyChat');
      
      // Set icon (use app icon)
      await _systemTray!.setImage('assets/icons/gold_with_text/256x256.png');
      
      debugPrint('✅ System tray initialized');
      debugPrint('💡 Click the system tray icon to see menu and show/hide the app');
    } catch (e) {
      debugPrint('⚠️ Failed to initialize system tray: $e');
    }
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
