import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/device_id.dart';
import '../../core/providers.dart';
import 'auth_provider.dart';

class QrLoginPanel extends ConsumerStatefulWidget {
  const QrLoginPanel({super.key});

  @override
  ConsumerState<QrLoginPanel> createState() => _QrLoginPanelState();
}

class _QrLoginPanelState extends ConsumerState<QrLoginPanel> {
  String? _qrUrl;
  String? _sessionToken;
  String? _error;
  bool _loading = true;
  bool _expired = false;
  Timer? _pollTimer;
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    _generateQrCode();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _generateQrCode() async {
    _pollTimer?.cancel();
    _expiryTimer?.cancel();

    setState(() {
      _loading = true;
      _error = null;
      _expired = false;
      _qrUrl = null;
      _sessionToken = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.createQrLoginSession();
      final data = response.data;
      if (data is! Map) {
        throw Exception('Invalid QR session response');
      }

      final qrUrl = data['qr_url']?.toString();
      final sessionToken = data['session_token']?.toString();
      if (qrUrl == null ||
          qrUrl.isEmpty ||
          sessionToken == null ||
          sessionToken.isEmpty) {
        throw Exception('Could not generate QR code');
      }

      if (!mounted) return;
      setState(() {
        _qrUrl = qrUrl;
        _sessionToken = sessionToken;
        _loading = false;
      });

      _startPolling(sessionToken);
      _expiryTimer = Timer(const Duration(minutes: 5), () {
        if (!mounted) return;
        setState(() => _expired = true);
        _pollTimer?.cancel();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _formatError(e);
      });
    }
  }

  String _formatError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
    }
    return 'Could not generate QR code. Please try again.';
  }

  void _startPolling(String sessionToken) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _pollStatus(sessionToken);
    });
  }

  Future<void> _pollStatus(String sessionToken) async {
    if (!mounted || _loading || _expired) return;

    try {
      final api = ref.read(apiServiceProvider);
      final deviceId = await getOrCreateDeviceId();
      final response = await api.pollQrLoginSession(
        sessionToken,
        deviceId: deviceId,
      );
      final data = response.data;
      if (data is! Map) return;

      final status = data['status']?.toString();
      if (status == 'authenticated') {
        _pollTimer?.cancel();
        _expiryTimer?.cancel();
        await ref.read(authProvider.notifier).completeAuthFromResponse(data);
        if (!mounted) return;
        final token = ref.read(authProvider).token;
        if ((token ?? '').isNotEmpty) {
          Navigator.of(context, rootNavigator: true).pop();
          context.go('/chats');
        }
      } else if (status == 'expired') {
        if (!mounted) return;
        setState(() => _expired = true);
        _pollTimer?.cancel();
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 && mounted) {
        setState(() => _expired = true);
        _pollTimer?.cancel();
      }
    } catch (_) {
      // Keep polling on transient errors.
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor =
        isDark ? const Color(0xFF8696A0) : const Color(0xFF667781);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Log in with QR code',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Open GekyChat on your phone, go to Linked Devices, tap Scan QR code, '
          'then scan this code to log in.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: mutedColor,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          )
        else if (_error != null)
          Column(
            children: [
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _generateQrCode,
                child: const Text('Try again'),
              ),
            ],
          )
        else if (_expired)
          Column(
            children: [
              Icon(
                Icons.timer_off_outlined,
                size: 48,
                color: mutedColor,
              ),
              const SizedBox(height: 12),
              Text(
                'QR code expired',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Generate a new code and scan again.',
                style: TextStyle(color: mutedColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _generateQrCode,
                child: const Text('Refresh QR code'),
              ),
            ],
          )
        else if (_qrUrl != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: _qrUrl!,
              version: QrVersions.auto,
              size: 220,
              backgroundColor: Colors.white,
            ),
          ),
        if (!_loading && _error == null && !_expired && _sessionToken != null) ...[
          const SizedBox(height: 16),
          Text(
            'Waiting for scan…',
            style: TextStyle(color: mutedColor, fontSize: 13),
          ),
        ],
      ],
    );
  }
}
