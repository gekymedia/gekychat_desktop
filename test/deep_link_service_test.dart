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

  test('parses gekychat://send?phone=&text=', () {
    final parsed = service.parseLink(
      'gekychat://send?phone=233508389213&text=Hi%20ADAMS',
    );
    expect(parsed?['route'], '/chats');
    expect(parsed?['sendPhone'], '233508389213');
    expect(parsed?['sendText'], 'Hi ADAMS');
  });
}
