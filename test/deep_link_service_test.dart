import 'package:flutter_test/flutter_test.dart';
import 'package:gekychat_desktop/src/core/services/deep_link_service.dart';

void main() {
  final service = DeepLinkService();

  test('parses gekychat://chat/{id} host form', () {
    final parsed = service.parseLink('gekychat://chat/872');
    expect(parsed?['route'], '/chats');
    expect(parsed?['conversationId'], '872');
  });

  test('parses gekychat:///chat/{id} path form', () {
    final parsed = service.parseLink('gekychat:///chat/872');
    expect(parsed?['route'], '/chats');
    expect(parsed?['conversationId'], '872');
  });

  test('parses gekychat://group/{id}', () {
    final parsed = service.parseLink('gekychat://group/42');
    expect(parsed?['route'], '/chats');
    expect(parsed?['groupId'], '42');
  });
}
