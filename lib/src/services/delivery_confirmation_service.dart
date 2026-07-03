import 'package:flutter/foundation.dart';
import '../core/api_service.dart';

/// Sends delivery confirmation when a received message is shown in the UI.
class DeliveryConfirmationService {
  final ApiService _api;
  final Set<int> _reported = {};

  DeliveryConfirmationService(this._api);

  void reportDelivered(int messageId) {
    if (messageId <= 0 || _reported.contains(messageId)) return;
    _reported.add(messageId);
    if (_reported.length > 500) {
      _reported.remove(_reported.first);
    }
    _api.markMessageDelivered(messageId).then((_) {}, onError: (e) {
      debugPrint('Delivery confirmation failed: $e');
      _reported.remove(messageId);
    });
  }
}
