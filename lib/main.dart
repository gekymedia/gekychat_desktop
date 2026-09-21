import 'dart:async';

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';
import 'src/core/services/desktop_window_service.dart';
import 'src/core/services/system_tray_service.dart';
import 'src/app_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'src/features/auth/auth_provider.dart';
import 'src/features/notifications/notification_manager.dart';
import 'src/core/providers.dart';
import 'src/core/services/taskbar_badge_service.dart';
import 'src/features/chats/sidebar_inbox_bump.dart';
import 'src/core/services/deep_link_service.dart';
import 'src/core/theme/theme_provider.dart' as custom_theme;
import 'src/core/theme/theme_service.dart';
import 'src/features/calls/incoming_call_handler.dart';
import 'src/features/calls/providers.dart';
import 'src/services/inbox_realtime_sync.dart';
import 'src/services/background_sync_worker.dart';
import 'src/widgets/keyboard_shortcuts_dialog.dart';
import 'src/widgets/livekit_call_overlay.dart';
import 'src/utils/world_feed_link_navigation.dart';
import 'src/widgets/desktop_typography.dart';
import 'src/widgets/desktop_shell_colors.dart';
import 'src/widgets/desktop_window_title_bar.dart';
import 'src/widgets/app_update_checker.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Telegram-style Open Sans — preload before first paint.
  await DesktopTypography.preload();
  
  // Initialize window manager for system tray support
  await windowManager.ensureInitialized();

  // Apply title bar + window chrome before first paint (matches saved app theme).
  final themeService = ThemeService();
  final initialTheme = await themeService.getThemeMode();
  final initialIsDark = initialTheme.isDark;

  final initialChrome =
      DesktopShellColors.shellChromeBackgroundStatic(isDark: initialIsDark);

  WindowOptions windowOptions = WindowOptions(
    size: Size(1280, 720),
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: initialChrome,
    skipTaskbar: false,
    titleBarStyle: DesktopWindowTitleBar.isSupported
        ? TitleBarStyle.hidden
        : TitleBarStyle.normal,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await DesktopWindowService.syncTitleBarTheme(
      initialIsDark,
      backgroundColor: initialChrome,
    );
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
  /// Stable across theme rebuilds so MaterialApp.router never swaps navigators.
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    
    // Soft 401: confirm via /me before wiping session (avoids abrupt logout)
    ref.read(apiServiceProvider).setOnUnauthorized(() {
      unawaited(ref.read(authProvider.notifier).handleUnauthorized());
    });
    
    // Set up window listener for close events
    windowManager.addListener(this);
    
    // Initialize system tray (WhatsApp-style background running)
    unawaited(SystemTrayService.initialize());
    
    // Initialize notifications asynchronously (one-time only)
    if (!_notificationsInitialized) {
      _notificationsInitialized = true;
      Future.microtask(() async {
        try {
          final apiService = ref.read(apiServiceProvider);
          // WidgetRef extends Ref, so we can pass it directly
          await NotificationManager.ensureReady(apiService, ref);
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
    _startRealtimeHealthCheck();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      BackgroundSyncWorker.attach(ProviderScope.containerOf(context));
      unawaited(BackgroundSyncWorker.initialize());
    });
    
    // Set up deep link handler
    widget.deepLinkService.setLinkHandler((link) {
      _handleDeepLink(link);
    });
  }
  
  void _handleDeepLink(String link) {
    if (!mounted) return;
    final uri = Uri.tryParse(link.trim());
    if (uri != null) {
      final worldTarget = parseWorldFeedTargetFromUri(uri);
      if (worldTarget != null) {
        final router = ref.read(routerProvider);
        openWorldFeedInAppWithRouter(
          ref,
          router,
          postId: worldTarget.postId,
          slug: worldTarget.slug,
        );
        debugPrint('🔗 World feed deep link: $link');
        return;
      }
    }
    final parsed = widget.deepLinkService.parseLink(link);
    if (parsed != null && mounted) {
      final route = parsed['route'];
      if (route != null) {
        final router = ref.read(routerProvider);
        const mainSections = [
          '/chats',
          '/status',
          '/channels',
          '/world',
          '/mail',
          '/ai',
          '/live-broadcast',
          '/calls',
          '/settings',
        ];
        if (mainSections.contains(route)) {
          ref.read(currentSectionProvider.notifier).setSection(route);
          router.go('/chats');
        } else {
          router.go(route);
        }
        // If there's a conversation/group/channel ID, we might need to handle it
        // in the specific screen
        debugPrint('🔗 Navigated to: $route');
      }
    }
  }
  
  void _startRealtimeHealthCheck() {
    Future.microtask(() async {
      while (mounted) {
        await Future.delayed(const Duration(seconds: 45));
        if (!mounted) break;
        try {
          final pusher = ref.read(pusherServiceProvider);
          if (!pusher.isConnected) {
            debugPrint('🔄 Realtime health: reconnecting Pusher…');
            unawaited(pusher.resetReconnectPolicyAndConnect());
            unawaited(
              ref.read(inboxRealtimeSyncProvider).initialize(force: true),
            );
            unawaited(BackgroundSyncWorker.triggerSync());
          }
        } catch (e) {
          debugPrint('Realtime health check failed: $e');
        }
      }
    });
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

  @override
  Future<void> onWindowClose() async {
    await DesktopWindowService.hideToTray();
  }

  @override
  void onWindowFocus() {
    try {
      unawaited(
        ref.read(incomingCallHandlerProvider).handleAppResumed(),
      );
      unawaited(
        ref.read(pusherServiceProvider).resetReconnectPolicyAndConnect(),
      );
      unawaited(
        ref.read(inboxRealtimeSyncProvider).initialize(force: true),
      );
      unawaited(BackgroundSyncWorker.triggerSync());
      unawaited(_retryPendingCallServerActions());
    } catch (_) {}
  }

  Future<void> _retryPendingCallServerActions() async {
    try {
      final cm = ref.read(callManagerProvider);
      await cm.retryPendingEndCalls();
      await cm.retryPendingLeaveCalls();
      await cm.retryPendingDeclineCalls();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    _router ??= ref.read(routerProvider);
    final router = _router!;
    final customThemeMode = ref.watch(custom_theme.themeModeProvider);
    final themeService = ref.watch(custom_theme.themeServiceProvider);

    ref.listen(custom_theme.themeModeProvider, (previous, next) {
      if (previous?.isDark == next.isDark) return;
      final chrome = DesktopShellColors.shellChromeBackgroundStatic(
        isDark: next.isDark,
      );
      unawaited(DesktopWindowService.syncTitleBarTheme(
        next.isDark,
        backgroundColor: chrome,
      ));
    });

    ref.listen(sidebarUnreadTotalProvider, (previous, next) {
      if (previous == next) return;
      unawaited(ref.read(taskbarBadgeServiceProvider).updateBadge());
    });

    return KeyboardShortcutHandler(
      child: MaterialApp.router(
        title: 'GekyChat Desktop',
        debugShowCheckedModeBanner: false,
        theme: themeService.getThemeData(customThemeMode),
        darkTheme: themeService.getThemeData(customThemeMode),
        themeMode: customThemeMode.isDark ? ThemeMode.dark : ThemeMode.light,
        routerConfig: router,
        builder: (context, child) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final chrome = DesktopShellColors.shellChromeBackground(
            context,
            isDark: isDark,
          );

          Widget content = child ?? const SizedBox.shrink();
          if (DesktopWindowTitleBar.isSupported) {
            content = ColoredBox(
              color: chrome,
              child: Column(
                children: [
                  const DesktopWindowTitleBar(),
                  Expanded(child: content),
                ],
              ),
            );
          }

          return AppUpdateChecker(
            child: Stack(
              alignment: Alignment.topLeft,
              clipBehavior: Clip.none,
              children: [
                content,
                const LiveKitCallOverlay(),
              ],
            ),
          );
        },
      ),
    );
  }
}
