import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../features/chats/models.dart';

/// Indexes GekyChat conversations/groups into iOS Spotlight (system search).
///
/// No-ops on non-iOS platforms. Native side: `ios/Runner/SpotlightPlugin.swift`.
class IosSpotlightService {
  IosSpotlightService._();
  static final IosSpotlightService instance = IosSpotlightService._();

  static const _channel = MethodChannel('gekychat/spotlight');
  static const _domainId = 'com.gekychat.spotlight';

  bool _handlerAttached = false;
  void Function(String link)? _onOpenLink;

  bool get isSupported => !kIsWeb && Platform.isIOS;

  /// Receive Spotlight taps as `gekychat://` deep links.
  void setOpenHandler(void Function(String link) handler) {
    _onOpenLink = handler;
    _ensureMethodHandler();
    if (!isSupported) return;
    unawaited(_consumePendingOpen());
  }

  void _ensureMethodHandler() {
    if (_handlerAttached || !isSupported) return;
    _handlerAttached = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onOpen') {
        final args = call.arguments;
        if (args is Map) {
          final link = args['link']?.toString();
          if (link != null && link.isNotEmpty) {
            _onOpenLink?.call(link);
          }
        }
      }
      return null;
    });
  }

  Future<void> _consumePendingOpen() async {
    try {
      final link = await _channel.invokeMethod<String>('getPendingOpen');
      if (link != null && link.isNotEmpty) {
        _onOpenLink?.call(link);
      }
    } catch (e) {
      debugPrint('Spotlight getPendingOpen failed: $e');
    }
  }

  Future<void> indexInbox({
    required List<ConversationSummary> conversations,
    required List<GroupSummary> groups,
  }) async {
    if (!isSupported) return;
    _ensureMethodHandler();

    final items = <Map<String, dynamic>>[];

    for (final c in conversations) {
      if (c.isSavedMessages) continue;
      final name = c.otherUser.name.trim();
      if (name.isEmpty || name == 'Unknown') continue;
      final phone = c.otherUser.phone?.trim();
      items.add({
        'id': 'chat:${c.id}',
        'title': name,
        'subtitle': phone?.isNotEmpty == true ? phone : 'GekyChat',
        'keywords': [
          name,
          if (phone != null && phone.isNotEmpty) phone,
          'GekyChat',
          'chat',
        ],
        'link': 'gekychat://chat/${c.id}',
        'type': 'chat',
      });
    }

    for (final g in groups) {
      final name = g.name.trim();
      if (name.isEmpty) continue;
      final isChannel = g.type == 'channel';
      items.add({
        'id': 'group:${g.id}',
        'title': name,
        'subtitle': isChannel ? 'Channel · GekyChat' : 'Group · GekyChat',
        'keywords': [
          name,
          'GekyChat',
          if (isChannel) 'channel' else 'group',
        ],
        'link': 'gekychat://group/${g.id}',
        'type': isChannel ? 'channel' : 'group',
      });
    }

    try {
      await _channel.invokeMethod('indexItems', {
        'domain': _domainId,
        'items': items,
      });
      debugPrint('Spotlight indexed ${items.length} chats/groups');
    } catch (e) {
      debugPrint('Spotlight index failed: $e');
    }
  }

  Future<void> clearAll() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('deleteAll', {'domain': _domainId});
    } catch (e) {
      debugPrint('Spotlight clear failed: $e');
    }
  }

  /// Helps Siri Suggestions / recents when the user opens a chat.
  Future<void> donateOpen({
    required String uniqueId,
    required String title,
    required String link,
  }) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('donateOpen', {
        'id': uniqueId,
        'title': title,
        'link': link,
      });
    } catch (e) {
      debugPrint('Spotlight donateOpen failed: $e');
    }
  }
}
