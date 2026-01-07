import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'auth_provider.dart';
import '../../core/providers.dart';
import 'package:dio/dio.dart';

class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginState();
}

class _PhoneLoginState extends ConsumerState<PhoneLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String? _validatePhone(String? v) {
    final s = (v ?? '').replaceAll(RegExp(r'\D'), '');
    if (s.isEmpty) return 'Please enter your phone number';
    if (!RegExp(r'^0\d{9}$').hasMatch(s)) {
      return 'Please enter a valid phone number (0XXXXXXXXX)';
    }
    return null;
  }


  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    _focusNode.unfocus();
    
    setState(() {
      _loading = true;
      _error = null;
    });

    final phone = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    await ref.read(authProvider.notifier).loginWithPhone(phone);

    if (!mounted) return;
    final err = ref.read(authProvider).error;
    if (err != null) {
      setState(() {
        _error = err;
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
      });
      context.go('/verify?phone=$phone');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(48),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo/Icon
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 64,
                      color: primaryColor,
                    ),
                    const SizedBox(height: 24),
                    
                    // Title
                    Text(
                      'Welcome to GekyChat',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your phone number to continue',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    
                    // Phone input
                    TextFormField(
                      controller: _phoneCtrl,
                      focusNode: _focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        hintText: '0XXXXXXXXX',
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                      ],
                      validator: _validatePhone,
                      onFieldSubmitted: (_) => _submit(),
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
                    
                    // Submit button
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
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
                          : const Text('Continue'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

