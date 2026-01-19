import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/feature_flags.dart';
import '../core/session.dart';
import '../core/providers.dart';

class SideNav extends ConsumerWidget {
  final String currentRoute;
  
  const SideNav({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Check feature flags
    final worldFeedEnabled = featureEnabled(ref, 'world_feed');
    final emailChatEnabled = featureEnabled(ref, 'email_chat');
    final advancedAiEnabled = featureEnabled(ref, 'advanced_ai');
    final liveBroadcastEnabled = featureEnabled(ref, 'live_broadcast');
    final channelsEnabled = featureEnabled(ref, 'channels_enabled');
    
    // Check username - use a simpler approach
    final userProfileAsync = ref.watch(currentUserProvider);
    final hasUsername = userProfileAsync.maybeWhen(
      data: (profile) => profile.hasUsername,
      orElse: () => false,
    );

    final navItems = <_NavItem>[
      _NavItem(
        icon: Icons.chat_bubble_outline,
        label: 'Chats',
        route: '/chats',
        isActive: currentRoute == '/chats',
      ),
      _NavItem(
        imageAsset: 'assets/icons/status_icon.png',
        label: 'Status',
        route: '/status',
        isActive: currentRoute == '/status',
      ),
      if (channelsEnabled)
        _NavItem(
          icon: Icons.campaign,
          label: 'Channels',
          route: '/channels',
          isActive: currentRoute.startsWith('/channels'),
        ),
      if (worldFeedEnabled && hasUsername)
        _NavItem(
          icon: Icons.explore,
          label: 'World',
          route: '/world',
          isActive: currentRoute == '/world',
        ),
      if (emailChatEnabled && hasUsername)
        _NavItem(
          icon: Icons.mail_outline,
          label: 'Mail',
          route: '/mail',
          isActive: currentRoute == '/mail',
        ),
      if (advancedAiEnabled)
        _NavItem(
          icon: Icons.smart_toy_outlined,
          label: 'AI',
          route: '/ai',
          isActive: currentRoute == '/ai',
        ),
      if (liveBroadcastEnabled)
        _NavItem(
          icon: Icons.videocam_outlined,
          label: 'Live',
          route: '/live-broadcast',
          isActive: currentRoute.startsWith('/live'),
        ),
      _NavItem(
        icon: Icons.phone_outlined,
        label: 'Calls',
        route: '/calls',
        isActive: currentRoute == '/calls',
      ),
      _NavItem(
        icon: Icons.settings_outlined,
        label: 'Settings',
        route: '/settings',
        isActive: currentRoute.startsWith('/settings'),
      ),
    ];

    return Container(
      width: 72,
      color: isDark ? const Color(0xFF202C33) : Colors.white,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              children: navItems.map((item) => _NavItemWidget(
                item: item,
                isDark: isDark,
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData? icon;
  final String? imageAsset; // For custom images like status icon
  final String label;
  final String route;
  final bool isActive;

  _NavItem({
    this.icon,
    this.imageAsset,
    required this.label,
    required this.route,
    required this.isActive,
  }) : assert(icon != null || imageAsset != null, 'Either icon or imageAsset must be provided');
}

class _NavItemWidget extends ConsumerWidget {
  final _NavItem item;
  final bool isDark;

  const _NavItemWidget({
    required this.item,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Main sections that should use provider instead of route navigation
    final mainSections = ['/chats', '/status', '/channels', '/world', '/mail', '/ai', '/live-broadcast', '/calls'];
    final isMainSection = mainSections.contains(item.route);
    
    return Tooltip(
      message: item.label,
      child: InkWell(
        onTap: () {
          if (isMainSection) {
            // Use provider for main sections to avoid route navigation
            ref.read(currentSectionProvider.notifier).setSection(item.route);
          } else {
            // Use context.go for external routes like /settings
            context.go(item.route);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: item.isActive
                ? (isDark ? const Color(0xFF0B8A6C) : const Color(0xFFDCF8C6))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            gradient: item.isActive
                ? const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFFF59E0B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              item.imageAsset != null
                  ? Image.asset(
                      item.imageAsset!,
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                      color: item.isActive
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.grey[600]),
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback to icon if image fails to load
                        return Icon(
                          Icons.circle_notifications,
                          color: item.isActive
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.grey[600]),
                          size: 24,
                        );
                      },
                    )
                  : Icon(
                      item.icon!,
                      color: item.isActive
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.grey[600]),
                      size: 24,
                    ),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: item.isActive ? FontWeight.w600 : FontWeight.normal,
                  color: item.isActive
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.grey[600]),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

