import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';

/// True if [text] is a GekyChat world-feed deep link (HTTPS or `gekychat://`).
bool looksLikeGekychatWorldFeedNavigationUrl(String text) {
  final t = text.trim();
  if (t.isEmpty) return false;
  final uri = Uri.tryParse(t);
  if (uri == null) return false;
  if (uri.scheme == 'gekychat') {
    return uri.host == 'world-feed' && uri.path.startsWith('/post/');
  }
  if ((uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host == 'chat.gekychat.com') {
    final p = uri.path;
    return p.startsWith('/wf/') || p.startsWith('/world-feed/post/');
  }
  return false;
}

/// Parsed world-feed target from a deep link URI.
({int? postId, String? slug})? parseWorldFeedTargetFromUri(Uri uri) {
  if (uri.scheme == 'gekychat' &&
      uri.host == 'world-feed' &&
      uri.path.startsWith('/post/')) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length >= 2 && segments[0] == 'post') {
      final idOrSlug = segments.last;
      if (idOrSlug.isEmpty) return null;
      final postId = int.tryParse(idOrSlug);
      return postId != null
          ? (postId: postId, slug: null)
          : (postId: null, slug: idOrSlug);
    }
  }
  if ((uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host == 'chat.gekychat.com') {
    final path = uri.path;
    if (path.startsWith('/wf/')) {
      final parts = path.split('/').where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2 && parts[0] == 'wf') {
        final code = parts[1];
        if (code.isNotEmpty) return (postId: null, slug: code);
      }
    }
    if (path.startsWith('/world-feed/post/')) {
      final parts = path.split('/').where((p) => p.isNotEmpty).toList();
      if (parts.length >= 3 &&
          parts[0] == 'world-feed' &&
          parts[1] == 'post') {
        final idOrSlug = parts[2];
        if (idOrSlug.isEmpty) return null;
        final postId = int.tryParse(idOrSlug);
        return postId != null
            ? (postId: postId, slug: null)
            : (postId: null, slug: idOrSlug);
      }
    }
  }
  return null;
}

/// Switch to World section and open the given post (numeric id or share slug).
void openWorldFeedInAppWithRouter(
  WidgetRef ref,
  GoRouter router, {
  int? postId,
  String? slug,
}) {
  if (postId == null && (slug == null || slug.isEmpty)) return;
  ref.read(currentSectionProvider.notifier).setSection('/world');

  // Main desktop shell uses `/chats` + [currentSectionProvider] for the content pane.
  // Do not `go('/world')` — that pins the router and breaks side-nav section switches.
  final path = router.routerDelegate.currentConfiguration.uri.path;
  const inAppShellRoutes = {
    '/chats',
    '/world',
    '/status',
    '/channels',
    '/mail',
    '/ai',
    '/live-broadcast',
    '/calls',
  };
  if (!inAppShellRoutes.contains(path)) {
    router.go('/chats');
  } else if (path != '/chats') {
    router.go('/chats');
  }

  if (postId != null) {
    ref.read(worldFeedNavigateToPostProvider.notifier).state = postId;
    ref.read(worldFeedNavigateToPostSlugProvider.notifier).state = null;
  } else {
    ref.read(worldFeedNavigateToPostSlugProvider.notifier).state = slug;
    ref.read(worldFeedNavigateToPostProvider.notifier).state = null;
  }
}

/// From widgets that have a [BuildContext] (e.g. message link tap).
void openWorldFeedInApp(
  WidgetRef ref,
  BuildContext context, {
  int? postId,
  String? slug,
}) {
  openWorldFeedInAppWithRouter(
    ref,
    GoRouter.of(context),
    postId: postId,
    slug: slug,
  );
}

/// Returns true if [urlString] was handled in-app (World + post).
bool tryOpenWorldFeedUrlInApp(
  WidgetRef ref,
  BuildContext context,
  String urlString,
) {
  var s = urlString.trim();
  if (s.startsWith('www.')) {
    s = 'https://$s';
  }
  final uri = Uri.tryParse(s);
  if (uri == null) return false;
  final target = parseWorldFeedTargetFromUri(uri);
  if (target == null) return false;
  openWorldFeedInApp(ref, context, postId: target.postId, slug: target.slug);
  return true;
}
