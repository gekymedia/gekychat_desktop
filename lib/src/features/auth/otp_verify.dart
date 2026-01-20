import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'auth_provider.dart';

class PasteIntent extends Intent {
  const PasteIntent();
}

class OtpPasteFormatter extends TextInputFormatter {
  final Function(String) onPaste;
  
  OtpPasteFormatter(this.onPaste);
  
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // If the new value has more than 1 character, it's likely a paste
    if (newValue.text.length > 1) {
      onPaste(newValue.text);
      // Return the old value to prevent the paste from going through
      return oldValue;
    }
    return newValue;
  }
}

class OtpVerifyScreen extends ConsumerStatefulWidget {
  final String phone;
  const OtpVerifyScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyState();
}

class _OtpVerifyState extends ConsumerState<OtpVerifyScreen> {
  final _nodes = List.generate(6, (_) => FocusNode());
  final _ctrls = List.generate(6, (_) => TextEditingController());
  bool _loading = false;
  String? _error;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown(30);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nodes.first.requestFocus();
    });
  }

  @override
  void dispose() {
    for (final n in _nodes) n.dispose();
    for (final c in _ctrls) c.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String get _code => _ctrls.map((c) => c.text).join();

  void _startCooldown([int seconds = 30]) {
    setState(() => _cooldown = seconds);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _verify() async {
    if (_code.length != 6) {
      setState(() => _error = 'Please enter the 6-digit code');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    await ref.read(authProvider.notifier).verifyOtp(widget.phone, _code);

    if (!mounted) return;
    final token = ref.read(authProvider).token;
    final err = ref.read(authProvider).error;

    if ((token ?? '').isNotEmpty) {
      context.go('/chats');
    } else {
      setState(() => _error = err ?? 'Verification failed.');
    }
    setState(() => _loading = false);
  }

  Future<void> _resend() async {
    if (_cooldown > 0) return;
    try {
      await ref.read(authProvider.notifier).loginWithPhone(widget.phone);
      _startCooldown(30);
      setState(() => _error = null);
    } catch (e) {
      setState(() => _error = 'Could not resend code. Please try again.');
    }
  }

  void _handlePaste(String text) {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    for (var i = 0; i < 6; i++) {
      _ctrls[i].text = i < digits.length ? digits[i] : '';
    }
    final next = digits.length >= 6 ? null : _nodes[digits.length];
    if (next != null) next.requestFocus();
    setState(() {});
  }

  Future<void> _handleClipboardPaste() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null && clipboardData!.text!.isNotEmpty) {
        _handlePaste(clipboardData.text!);
      }
    } catch (e) {
      debugPrint('Failed to read clipboard: $e');
    }
  }

  Widget _otpBox(int i) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 48,
      height: 56,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF202C33) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _nodes[i].hasFocus
              ? Theme.of(context).colorScheme.primary
              : (isDark ? const Color(0xFF3B4A54) : Colors.grey[300]!),
          width: 2,
        ),
      ),
      child: TextField(
        controller: _ctrls[i],
        focusNode: _nodes[i],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          OtpPasteFormatter((text) => _handlePaste(text)),
          LengthLimitingTextInputFormatter(1), // Limit to 1 character after paste handling
        ],
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onTap: () {
          // Check clipboard when user taps on any field
          _handleClipboardPaste();
        },
        onChanged: (v) {
          if (v.length > 1) {
            _handlePaste(v);
            return;
          }
          if (v.isNotEmpty && i < 5) _nodes[i + 1].requestFocus();
          if (v.isEmpty && i > 0) _nodes[i - 1].requestFocus();
          if (_code.length == 6) _verify();
          setState(() {});
        },
        onSubmitted: (_) => i == 5 ? _verify() : _nodes[i + 1].requestFocus(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () {
            context.go('/login');
          },
          tooltip: 'Back to phone number',
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/icons/gold_no_text/128x128.png',
                    width: 128,
                    height: 128,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback to icon if image not found
                      return Icon(
                        Icons.sms_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Verification Code',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the code sent to\n${widget.phone}',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      context.go('/login');
                    },
                    icon: Icon(
                      Icons.edit,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    label: Text(
                      'Change phone number',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // OTP boxes
                  Shortcuts(
                    shortcuts: {
                      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyV): const PasteIntent(),
                      LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyV): const PasteIntent(),
                    },
                    child: Actions(
                      actions: {
                        PasteIntent: CallbackAction<PasteIntent>(
                          onInvoke: (intent) => _handleClipboardPaste(),
                        ),
                      },
                      child: Focus(
                        autofocus: false,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              6,
                              (i) => Padding(
                                padding: EdgeInsets.only(
                                  right: i < 5 ? 8 : 0,
                                ),
                                child: _otpBox(i),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Error message
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ),
                  
                  // Resend button
                  TextButton(
                    onPressed: _cooldown > 0 || _loading ? null : _resend,
                    child: Text(
                      _cooldown > 0
                          ? 'Resend code in $_cooldown seconds'
                          : 'Resend code',
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Verify button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading || _code.length != 6 ? null : _verify,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Verify'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

