import 'package:flutter/foundation.dart';

/// Service to handle deep links from web to desktop app
/// Supports gekychat:// protocol links
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  String? _pendingLink;
  Function(String)? _onLinkReceived;
  List<String> _commandLineArgs = [];

  /// Initialize the deep link service with command line arguments.
  /// The OS passes `gekychat://...` as argv when the protocol handler runs.
  Future<void> initialize({List<String>? args}) async {
    _commandLineArgs = args ?? [];

    if (_commandLineArgs.isNotEmpty) {
      final protocolLink = _commandLineArgs.firstWhere(
        (arg) => arg.startsWith('gekychat://'),
        orElse: () => '',
      );
      if (protocolLink.isNotEmpty) {
        _handleLink(protocolLink);
      }
    }
  }
  
  /// Handle a new link (can be called from external sources)
  void handleLink(String link) {
    _handleLink(link);
  }

  /// Handle a deep link
  void _handleLink(String link) {
    debugPrint('🔗 Deep link received: $link');
    _pendingLink = link;
    if (_onLinkReceived != null) {
      _onLinkReceived!(link);
      _pendingLink = null;
    }
  }

  /// Set callback for when a link is received
  void setLinkHandler(Function(String) handler) {
    _onLinkReceived = handler;
    // If there's a pending link, handle it now
    if (_pendingLink != null) {
      handler(_pendingLink!);
      _pendingLink = null;
    }
  }

  /// Parse a gekychat:// URL and extract route information
  Map<String, String>? parseLink(String link) {
    if (!link.startsWith('gekychat://')) {
      return null;
    }

    try {
      final uri = Uri.parse(link);
      final path = uri.path;
      final queryParams = uri.queryParameters;

      // `gekychat://web?url=...` from the Laravel web app: `web` is the host,
      // not the path (path is empty). Also accept `gekychat:///web?url=...`.
      final isWebBridge = queryParams.containsKey('url') &&
          (uri.host == 'web' || path == 'web' || path == '/web');

      // Handle web?url parameter (from web interface)
      if (isWebBridge) {
        final webUrl = queryParams['url']!;
        try {
          final webUri = Uri.parse(webUrl);
          final webPath = webUri.path;
          
          // Map web paths to desktop routes
          if (webPath.startsWith('/c/')) {
            // /c/{conversationId} -> /chats
            final conversationId = webPath.split('/').last;
            return {
              'route': '/chats',
              'conversationId': conversationId,
            };
          } else if (webPath.startsWith('/g/')) {
            // /g/{groupId} -> /chats
            final groupId = webPath.split('/').last;
            return {
              'route': '/chats',
              'groupId': groupId,
            };
          } else if (webPath.startsWith('/channels')) {
            return {'route': '/channels'};
          } else if (webPath.startsWith('/settings')) {
            return {'route': '/settings'};
          } else if (webPath.startsWith('/calls')) {
            return {'route': '/calls'};
          } else if (webPath.startsWith('/status')) {
            return {'route': '/status'};
          } else if (webPath.startsWith('/world-feed')) {
            return {'route': '/world'};
          }
        } catch (e) {
          debugPrint('Error parsing web URL: $e');
        }
        // Default: go to chats
        return {'route': '/chats'};
      }

      // Parse direct protocol routes
      // gekychat://chat/{conversationId}
      // gekychat://group/{groupId}
      // gekychat://channel/{channelId}
      // gekychat://user/{userId}
      // gekychat://settings
      // gekychat://calls

      if (path.isEmpty || path == '/') {
        return {'route': '/chats'};
      }

      final segments = path.split('/').where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) {
        return {'route': '/chats'};
      }

      final routeType = segments[0];
      final routeId = segments.length > 1 ? segments[1] : null;

      switch (routeType) {
        case 'chat':
          if (routeId != null) {
            return {
              'route': '/chats',
              'conversationId': routeId,
            };
          }
          return {'route': '/chats'};
        case 'group':
          if (routeId != null) {
            return {
              'route': '/chats',
              'groupId': routeId,
            };
          }
          return {'route': '/chats'};
        case 'channel':
          if (routeId != null) {
            return {
              'route': '/channels',
              'channelId': routeId,
            };
          }
          return {'route': '/channels'};
        case 'user':
          if (routeId != null) {
            return {
              'route': '/chats',
              'userId': routeId,
            };
          }
          return {'route': '/chats'};
        case 'settings':
          return {'route': '/settings'};
        case 'calls':
          return {'route': '/calls'};
        case 'status':
          return {'route': '/status'};
        case 'world':
          return {'route': '/world'};
        default:
          return {'route': '/chats'};
      }
    } catch (e) {
      debugPrint('Error parsing deep link: $e');
      return {'route': '/chats'};
    }
  }
}
