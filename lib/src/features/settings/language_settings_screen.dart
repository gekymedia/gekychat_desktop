import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported languages with their display names and native names
class AppLanguage {
  final String code;
  final String name;
  final String nativeName;
  final bool isRTL;

  const AppLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    this.isRTL = false,
  });

  static const systemDefault = AppLanguage(
    code: 'system',
    name: 'System default',
    nativeName: 'System default',
  );

  static const List<AppLanguage> supportedLanguages = [
    systemDefault,
    AppLanguage(code: 'en', name: 'English', nativeName: 'English'),
    AppLanguage(code: 'es', name: 'Spanish', nativeName: 'Español'),
    AppLanguage(code: 'fr', name: 'French', nativeName: 'Français'),
    AppLanguage(code: 'de', name: 'German', nativeName: 'Deutsch'),
    AppLanguage(code: 'pt', name: 'Portuguese', nativeName: 'Português'),
    AppLanguage(code: 'ru', name: 'Russian', nativeName: 'Русский'),
    AppLanguage(code: 'ar', name: 'Arabic', nativeName: 'العربية', isRTL: true),
    AppLanguage(code: 'zh', name: 'Chinese (Simplified)', nativeName: '简体中文'),
    AppLanguage(code: 'zh_TW', name: 'Chinese (Traditional)', nativeName: '繁體中文'),
    AppLanguage(code: 'ja', name: 'Japanese', nativeName: '日本語'),
    AppLanguage(code: 'ko', name: 'Korean', nativeName: '한국어'),
    AppLanguage(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी'),
    AppLanguage(code: 'it', name: 'Italian', nativeName: 'Italiano'),
    AppLanguage(code: 'nl', name: 'Dutch', nativeName: 'Nederlands'),
    AppLanguage(code: 'pl', name: 'Polish', nativeName: 'Polski'),
    AppLanguage(code: 'tr', name: 'Turkish', nativeName: 'Türkçe'),
    AppLanguage(code: 'id', name: 'Indonesian', nativeName: 'Bahasa Indonesia'),
    AppLanguage(code: 'vi', name: 'Vietnamese', nativeName: 'Tiếng Việt'),
    AppLanguage(code: 'th', name: 'Thai', nativeName: 'ไทย'),
    AppLanguage(code: 'uk', name: 'Ukrainian', nativeName: 'Українська'),
    AppLanguage(code: 'cs', name: 'Czech', nativeName: 'Čeština'),
    AppLanguage(code: 'sv', name: 'Swedish', nativeName: 'Svenska'),
    AppLanguage(code: 'da', name: 'Danish', nativeName: 'Dansk'),
    AppLanguage(code: 'fi', name: 'Finnish', nativeName: 'Suomi'),
    AppLanguage(code: 'no', name: 'Norwegian', nativeName: 'Norsk'),
    AppLanguage(code: 'el', name: 'Greek', nativeName: 'Ελληνικά'),
    AppLanguage(code: 'he', name: 'Hebrew', nativeName: 'עברית', isRTL: true),
    AppLanguage(code: 'ro', name: 'Romanian', nativeName: 'Română'),
    AppLanguage(code: 'hu', name: 'Hungarian', nativeName: 'Magyar'),
    AppLanguage(code: 'ms', name: 'Malay', nativeName: 'Bahasa Melayu'),
    AppLanguage(code: 'bn', name: 'Bengali', nativeName: 'বাংলা'),
    AppLanguage(code: 'ta', name: 'Tamil', nativeName: 'தமிழ்'),
    AppLanguage(code: 'te', name: 'Telugu', nativeName: 'తెలుగు'),
    AppLanguage(code: 'mr', name: 'Marathi', nativeName: 'मराठी'),
    AppLanguage(code: 'ur', name: 'Urdu', nativeName: 'اردو', isRTL: true),
    AppLanguage(code: 'fa', name: 'Persian', nativeName: 'فارسی', isRTL: true),
    AppLanguage(code: 'sw', name: 'Swahili', nativeName: 'Kiswahili'),
    AppLanguage(code: 'fil', name: 'Filipino', nativeName: 'Filipino'),
  ];

  static AppLanguage fromCode(String code) {
    return supportedLanguages.firstWhere(
      (lang) => lang.code == code,
      orElse: () => systemDefault,
    );
  }
}

/// Provider for app language preference
final appLanguageProvider = StateNotifierProvider<AppLanguageNotifier, AppLanguage>((ref) {
  return AppLanguageNotifier();
});

class AppLanguageNotifier extends StateNotifier<AppLanguage> {
  AppLanguageNotifier() : super(AppLanguage.systemDefault) {
    _loadPreference();
  }

  static const String _prefKey = 'app_language_code';

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefKey) ?? 'system';
    state = AppLanguage.fromCode(code);
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, language.code);
  }

  Locale? get locale {
    if (state.code == 'system') return null;
    if (state.code.contains('_')) {
      final parts = state.code.split('_');
      return Locale(parts[0], parts[1]);
    }
    return Locale(state.code);
  }
}

/// Language settings screen
class LanguageSettingsScreen extends ConsumerStatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  ConsumerState<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends ConsumerState<LanguageSettingsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppLanguage> get _filteredLanguages {
    if (_searchQuery.isEmpty) {
      return AppLanguage.supportedLanguages;
    }
    final query = _searchQuery.toLowerCase();
    return AppLanguage.supportedLanguages.where((lang) {
      return lang.name.toLowerCase().contains(query) ||
          lang.nativeName.toLowerCase().contains(query) ||
          lang.code.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedLanguage = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : Colors.grey[100],
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.white,
        title: Text(
          'App Language',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: isDark ? const Color(0xFF202C33) : Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'Search languages...',
                hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                prefixIcon: Icon(
                  Icons.search,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF0B141A) : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Info text
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark ? const Color(0xFF0B141A) : Colors.grey[100],
            child: Text(
              'Choose the language for the app interface. This will override your device language setting.',
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
                fontSize: 13,
              ),
            ),
          ),

          // Language list
          Expanded(
            child: ListView.builder(
              itemCount: _filteredLanguages.length,
              itemBuilder: (context, index) {
                final language = _filteredLanguages[index];
                final isSelected = language.code == selectedLanguage.code;
                final isSystemDefault = language.code == 'system';

                return Container(
                  color: isDark ? const Color(0xFF202C33) : Colors.white,
                  child: Column(
                    children: [
                      ListTile(
                        onTap: () async {
                          await ref.read(appLanguageProvider.notifier).setLanguage(language);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isSystemDefault
                                      ? 'Language set to system default'
                                      : 'Language changed to ${language.name}',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        leading: isSystemDefault
                            ? Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white12 : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.phone_android,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              )
                            : Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _getLanguageColor(language.code).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  language.code.toUpperCase().substring(0, 2),
                                  style: TextStyle(
                                    color: _getLanguageColor(language.code),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                        title: Text(
                          language.name,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: isSystemDefault
                            ? Text(
                                'Uses your device language',
                                style: TextStyle(
                                  color: isDark ? Colors.white54 : Colors.black54,
                                  fontSize: 13,
                                ),
                              )
                            : Text(
                                language.nativeName,
                                style: TextStyle(
                                  color: isDark ? Colors.white54 : Colors.black54,
                                  fontSize: 13,
                                ),
                              ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: theme.colorScheme.primary,
                              )
                            : null,
                      ),
                      if (index < _filteredLanguages.length - 1)
                        Divider(
                          height: 1,
                          indent: 72,
                          color: isDark ? Colors.white12 : Colors.grey[300],
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getLanguageColor(String code) {
    final colors = {
      'en': Colors.blue,
      'es': Colors.orange,
      'fr': Colors.indigo,
      'de': Colors.amber,
      'pt': Colors.green,
      'ru': Colors.red,
      'ar': Colors.teal,
      'zh': Colors.red[700]!,
      'zh_TW': Colors.red[700]!,
      'ja': Colors.pink,
      'ko': Colors.purple,
      'hi': Colors.deepOrange,
      'it': Colors.green[700]!,
      'nl': Colors.orange[700]!,
      'pl': Colors.red[400]!,
      'tr': Colors.red[600]!,
      'id': Colors.red[800]!,
      'vi': Colors.yellow[700]!,
      'th': Colors.blue[700]!,
      'uk': Colors.blue[400]!,
      'cs': Colors.blue[800]!,
      'sv': Colors.blue[600]!,
      'da': Colors.red[300]!,
      'fi': Colors.blue[200]!,
      'no': Colors.red[500]!,
      'el': Colors.blue[900]!,
      'he': Colors.blue[500]!,
      'ro': Colors.yellow[800]!,
      'hu': Colors.green[600]!,
      'ms': Colors.yellow[600]!,
      'bn': Colors.green[800]!,
      'ta': Colors.orange[800]!,
      'te': Colors.orange[600]!,
      'mr': Colors.orange[400]!,
      'ur': Colors.green[400]!,
      'fa': Colors.green[500]!,
      'sw': Colors.black,
      'fil': Colors.blue[300]!,
    };
    return colors[code] ?? Colors.grey;
  }
}
