import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_service.dart';
import 'providers.dart';

/// MEDIA COMPRESSION: Service to poll attachment compression status
/// 
/// Polls attachment status until compression is complete or failed
/// Used to update UI when compression finishes
class CompressionStatusPoller {
  final ApiService _apiService;
  final Map<int, Timer> _activePolls = {};

  CompressionStatusPoller(this._apiService);

  /// Start polling an attachment's compression status
  /// 
  /// [onStatusUpdate] is called when status changes
  /// [onComplete] is called when compression completes (success or failure)
  /// 
  /// Returns a function to cancel polling
  Future<Function()> pollAttachmentStatus({
    required int attachmentId,
    required Function(Map<String, dynamic>) onStatusUpdate,
    Function()? onComplete,
    Duration pollInterval = const Duration(seconds: 2),
    Duration maxPollDuration = const Duration(minutes: 5),
  }) async {
    final startTime = DateTime.now();
    
    Timer? timer;
    
    timer = Timer.periodic(pollInterval, (timer) async {
      // Check max duration
      if (DateTime.now().difference(startTime) > maxPollDuration) {
        timer.cancel();
        _activePolls.remove(attachmentId);
        return;
      }

      try {
        final response = await _apiService.getAttachment(attachmentId);
        final data = response.data['data'] ?? response.data;
        final status = data['compression_status'] as String?;
        
        // Call status update callback
        onStatusUpdate(data);
        
        // If compression is complete or failed, stop polling
        if (status == 'completed' || status == 'failed') {
          timer.cancel();
          _activePolls.remove(attachmentId);
          onComplete?.call();
        }
      } catch (e) {
        // Poll failed, stop polling
        timer.cancel();
        _activePolls.remove(attachmentId);
      }
    });

    _activePolls[attachmentId] = timer;

    // Return cancel function
    return () {
      timer?.cancel();
      _activePolls.remove(attachmentId);
    };
  }

  /// Cancel polling for a specific attachment
  void cancelPoll(int attachmentId) {
    _activePolls[attachmentId]?.cancel();
    _activePolls.remove(attachmentId);
  }

  /// Cancel all active polls
  void cancelAllPolls() {
    for (final timer in _activePolls.values) {
      timer.cancel();
    }
    _activePolls.clear();
  }
}

final compressionStatusPollerProvider = Provider<CompressionStatusPoller>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return CompressionStatusPoller(apiService);
});

