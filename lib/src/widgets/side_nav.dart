import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/feature_flags.dart';
import '../core/session.dart';
import '../core/providers.dart';
import '../features/chats/sidebar_inbox_bump.dart';
import '../services/product_analytics_service.dart';
import '../features/multi_account/account_switcher_screen.dart';
import 'colored_avatar.dart';
import 'desktop_shell_colors.dart';
import 'gekychat_ai_icon.dart';

class SideNav extends ConsumerWidget {
  final String currentRoute;
  final Color backgroundColor;

  const SideNav({
    super.key,
    required this.currentRoute,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatsUnread = ref.watch(sidebarUnreadTotalProvider);

    final emailChatEnabled = featureEnabled(ref, 'email_chat');
    final advancedAiEnabled = featureEnabled(ref, 'advanced_ai');
    final liveBroadcastEnabled = featureEnabled(ref, 'live_broadcast');
    final channelsEnabled = featureEnabled(ref, 'channels_enabled');

    final userProfileAsync = ref.watch(currentUserProvider);
    final hasUsername = userProfileAsync.maybeWhen(
      data: (profile) => profile.hasUsername,
      orElse: () => false,
    );

    final primaryItems = <_NavItem>[
      _NavItem(
        icon: Icons.chat_bubble_outline,
        label: chatsUnread > 0 ? 'Chats — $chatsUnread unread' : 'Chats',
        route: '/chats',
        isActive: currentRoute == '/chats',
        badgeCount: chatsUnread,
        highlightWhenUnread: true,
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
          label: 'GekyChat AI',
          route: '/ai',
          isActive: currentRoute == '/ai',
          iconBuilder: (onAccentBackground) => GekyChatAiIcon(
            size: 24,
            onAccentBackground: onAccentBackground,
          ),
        ),
      if (liveBroadcastEnabled)
        _NavItem(
          icon: Icons.videocam_outlined,
          label: 'Live',
          route: '/live-broadcast',
          isActive: currentRoute == '/live-broadcast' ||
              currentRoute.startsWith('/live-broadcast'),
        ),
      _NavItem(
        icon: Icons.phone_outlined,
        label: 'Calls',
        route: '/calls',
        isActive: currentRoute == '/calls',
      ),
    ];

    final settingsActive = currentRoute.startsWith('/settings');
    final bottomWithActive = <_NavItem>[
      _NavItem(
        icon: Icons.settings_outlined,
        label: 'Settings',
        route: '/settings',
        isActive: settingsActive,
      ),
    ];

    return Container(
      width: DesktopShellColors.railWidth,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          right: BorderSide(
            color: DesktopShellColors.railDivider(isDark),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              children: primaryItems
                  .map(
                    (item) => _NavItemWidget(
                      item: item,
                      isDark: isDark,
                    ),
                  )
                  .toList(),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: _RailProfileButton(
              userProfileAsync: userProfileAsync,
              isDark: isDark,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: _NavItemWidget(
              item: bottomWithActive.first,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _RailProfileButton extends StatelessWidget {
  const _RailProfileButton({
    required this.userProfileAsync,
    required this.isDark,
  });

  final AsyncValue<UserProfile> userProfileAsync;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    void openSwitcher() {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
            child: const AccountSwitcherScreen(),
          ),
        ),
      );
    }

    return userProfileAsync.when(
      data: (profile) {
        return Tooltip(
          message: '${profile.name}\nSwitch account',
          child: InkWell(
            onTap: openSwitcher,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ColoredAvatar(
                imageUrl: profile.avatarUrl,
                name: profile.name,
                radius: 18,
              ),
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => Tooltip(
        message: 'Switch account',
        child: InkWell(
          onTap: openSwitcher,
          borderRadius: BorderRadius.circular(12),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Icon(Icons.account_circle_outlined, size: 40),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData? icon;
  final String? imageAsset;
  final Widget Function(bool onAccentBackground)? iconBuilder;
  final String label;
  final String route;
  final bool isActive;
  /// Unread / notification count shown as a green pill on the rail icon.
  final int badgeCount;
  /// When true and [badgeCount] > 0 while inactive, tint the icon green
  /// (same accent as the active rail tile / iOS unread chrome).
  final bool highlightWhenUnread;

  const _NavItem({
    this.icon,
    this.imageAsset,
    this.iconBuilder,
    required this.label,
    required this.route,
    required this.isActive,
    this.badgeCount = 0,
    this.highlightWhenUnread = false,
  }) : assert(
          icon != null || imageAsset != null || iconBuilder != null,
          'Provide icon, imageAsset, or iconBuilder',
        );
}

class _NavItemWidget extends ConsumerStatefulWidget {
  final _NavItem item;
  final bool isDark;

  const _NavItemWidget({
    required this.item,
    required this.isDark,
  });

  @override
  ConsumerState<_NavItemWidget> createState() => _NavItemWidgetState();
}

class _NavItemWidgetState extends ConsumerState<_NavItemWidget> {
  static const _accent = Color(0xFF008069);
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
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
    final isMainSection = mainSections.contains(widget.item.route);

    final isDark = widget.isDark;
    final idleIconColor = isDark ? Colors.white70 : const Color(0xFF667781);
    final activeIconColor = Colors.white;
    final isActive = widget.item.isActive;
    final hasUnread = widget.item.badgeCount > 0;
    final unreadHighlight =
        !isActive && hasUnread && widget.item.highlightWhenUnread;
    final iconColor = isActive
        ? activeIconColor
        : (unreadHighlight ? _accent : idleIconColor);

    final activeBg = _accent;
    final unreadIdleBg = _accent.withValues(alpha: isDark ? 0.18 : 0.12);
    final hoverBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);

    Widget iconChild;
    if (widget.item.iconBuilder != null) {
      iconChild = widget.item.iconBuilder!(isActive);
    } else if (widget.item.imageAsset != null) {
      iconChild = Image.asset(
        widget.item.imageAsset!,
        width: 24,
        height: 24,
        fit: BoxFit.contain,
        color: iconColor,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.circle_notifications,
            color: iconColor,
            size: 24,
          );
        },
      );
    } else {
      iconChild = Icon(
        widget.item.icon!,
        color: iconColor,
        size: 24,
      );
    }

    if (hasUnread) {
      final label = widget.item.badgeCount > 99
          ? '99+'
          : '${widget.item.badgeCount}';
      iconChild = Badge(
        backgroundColor: isActive ? Colors.white : _accent,
        textColor: isActive ? _accent : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        child: iconChild,
      );
    }

    return Tooltip(
      message: widget.item.label,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: InkWell(
          onTap: () {
            if (isMainSection) {
              ref.read(currentSectionProvider.notifier).setSection(widget.item.route);
              unawaited(ref.read(productAnalyticsProvider).trackFeature(widget.item.route));
            } else {
              context.go(widget.item.route);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: double.infinity,
            height: 44,
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? activeBg
                  : unreadHighlight
                      ? (_hovered ? hoverBg : unreadIdleBg)
                      : (_hovered ? hoverBg : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: iconChild),
          ),
        ),
      ),
    );
  }
}
