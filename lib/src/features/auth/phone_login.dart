import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_provider.dart';
import '../../app_router.dart';
import '../../utils/phone_matcher.dart';
import '../../utils/snackbar_helper.dart';
import 'login_countries.dart';
import 'qr_login_panel.dart';

const _termsOfServiceUrl = 'https://gekychat.com/terms-of-service';
const _privacyPolicyUrl = 'https://gekychat.com/privacy-policy';

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
  LoginCountry _selectedCountry = kDefaultLoginCountry;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String? _validatePhone(String? v) {
    if (!_selectedCountry.supported) {
      return 'Phone login is only available for Ghana (+233) at the moment';
    }
    if ((v ?? '').trim().isEmpty) return 'Please enter your phone number';
    if (!PhoneMatcher.isValidGhanaLoginPhone(v)) {
      return 'Enter a valid mobile number';
    }
    return null;
  }

  void _showUnsupportedCountryNotice(LoginCountry country) {
    context.showInfoToast('${country.name} is not supported yet');
    setState(() => _selectedCountry = kDefaultLoginCountry);
  }

  void _onCountrySelected(LoginCountry country) {
    if (!country.supported) {
      _showUnsupportedCountryNotice(country);
      return;
    }
    setState(() => _selectedCountry = country);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        context.showErrorToast('Could not open $url');
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Could not open link: $e');
      }
    }
  }

  Future<void> _showCountryPicker() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    var query = '';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final q = query.trim().toLowerCase();
            final filtered = loginCountriesSorted.where((c) {
              if (q.isEmpty) return true;
              return c.name.toLowerCase().contains(q) ||
                  c.dialCode.contains(q) ||
                  c.code.toLowerCase().contains(q);
            }).toList();

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
              title: Text(
                'Select country',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF111B21),
                ),
              ),
              content: SizedBox(
                width: 420,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      onChanged: (v) => setDialogState(() => query = v),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search country',
                        prefixIcon: const Icon(Icons.search, size: 22),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF111B21)
                            : const Color(0xFFF0F2F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final country = filtered[i];
                          final selected =
                              country.code == _selectedCountry.code;
                          return ListTile(
                            leading: Text(
                              country.flag,
                              style: const TextStyle(fontSize: 24),
                            ),
                            title: Text(
                              country.name,
                              style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            trailing: Text(
                              country.dialCode,
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFF8696A0)
                                    : const Color(0xFF667781),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            selected: selected,
                            onTap: () {
                              Navigator.pop(dialogContext);
                              _onCountrySelected(country);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showQrLogin() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          content: const SizedBox(
            width: 380,
            child: QrLoginPanel(),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (_loading) {
      debugPrint('🔵 Already submitting, ignoring duplicate call');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    _focusNode.unfocus();

    setState(() {
      _loading = true;
      _error = null;
    });

    final phone = PhoneMatcher.normalizeGhanaLoginPhone(_phoneCtrl.text);

    final router = ref.read(routerProvider);

    try {
      debugPrint('🔵 Starting login with phone: $phone');
      await ref.read(authProvider.notifier).loginWithPhone(phone);
      debugPrint('🔵 loginWithPhone completed');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint('✅ OTP request successful, navigating to /verify?phone=$phone');
        router.go('/verify?phone=$phone');
        debugPrint('🔵 Navigation call completed');
      });
    } catch (e, stackTrace) {
      debugPrint('❌ Login exception: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final mutedColor =
        isDark ? const Color(0xFF8696A0) : const Color(0xFF667781);

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
                    Image.asset(
                      'assets/icons/gold_no_text/128x128.png',
                      width: 128,
                      height: 128,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: primaryColor,
                        );
                      },
                    ),
                    const SizedBox(height: 24),
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
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF2A3942)
                              : const Color(0xFFE4E6EB),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _showCountryPicker,
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(11),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _selectedCountry.flag,
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _selectedCountry.dialCode,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_drop_down,
                                      color: mutedColor,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 28,
                            color: isDark
                                ? const Color(0xFF2A3942)
                                : const Color(0xFFE4E6EB),
                          ),
                          Expanded(
                            child: TextFormField(
                              controller: _phoneCtrl,
                              focusNode: _focusNode,
                              decoration: const InputDecoration(
                                hintText: '24 123 4567',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                              ),
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              validator: _validatePhone,
                              onFieldSubmitted: (_) => _submit(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(color: mutedColor.withValues(alpha: 0.4)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: mutedColor,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        Expanded(
                          child: Divider(color: mutedColor.withValues(alpha: 0.4)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _showQrLogin,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Log in with QR code'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'By continuing, you agree to our ',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: mutedColor,
                              ),
                        ),
                        TextButton(
                          onPressed: () => _openUrl(_termsOfServiceUrl),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: primaryColor,
                          ),
                          child: const Text('Terms of Service'),
                        ),
                        Text(
                          ' and ',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: mutedColor,
                              ),
                        ),
                        TextButton(
                          onPressed: () => _openUrl(_privacyPolicyUrl),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: primaryColor,
                          ),
                          child: const Text('Privacy Policy'),
                        ),
                        Text(
                          '.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: mutedColor,
                              ),
                        ),
                      ],
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
