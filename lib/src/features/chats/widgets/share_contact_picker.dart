import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../utils/phone_matcher.dart';
import '../../../widgets/colored_avatar.dart';
import '../../contacts/contacts_repository.dart';
import '../models.dart';

Future<int?> showShareContactPicker({
  required BuildContext context,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showDialog<int>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (dialogContext) {
      final dialogHeight = MediaQuery.sizeOf(context).height * 0.8;

      return Dialog(
        backgroundColor: isDark ? const Color(0xFF111B21) : Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SizedBox(
          width: 440,
          height: dialogHeight,
          child: const ShareContactPicker(),
        ),
      );
    },
  );
}

class ShareContactPicker extends ConsumerStatefulWidget {
  const ShareContactPicker({super.key});

  @override
  ConsumerState<ShareContactPicker> createState() => _ShareContactPickerState();
}

class _ShareContactPickerState extends ConsumerState<ShareContactPicker> {
  final _searchController = TextEditingController();
  final _contacts = <GekyContact>[];
  var _filteredContacts = <GekyContact>[];
  var _initialLoading = true;
  var _loadingMore = false;
  var _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadContacts());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
      _applyFilter();
    });
  }

  String _displayName(GekyContact contact) {
    final name = contact.name.trim();
    if (name.isNotEmpty) return name;
    final fromUser = contact.contactUser?['name'];
    if (fromUser is String && fromUser.trim().isNotEmpty) {
      return fromUser.trim();
    }
    final phone = contact.phone?.trim();
    return phone?.isNotEmpty == true ? phone! : 'Unknown';
  }

  String? _phone(GekyContact contact) {
    final fromUser = contact.contactUser?['phone'];
    if (fromUser is String && fromUser.trim().isNotEmpty) {
      return fromUser.trim();
    }
    return contact.phone?.trim();
  }

  void _sortContacts() {
    _contacts.sort(
      (a, b) => _displayName(a).toLowerCase().compareTo(
            _displayName(b).toLowerCase(),
          ),
    );
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredContacts = List<GekyContact>.from(_contacts);
      return;
    }

    final queryDigits = PhoneMatcher.normalize(_searchQuery);
    _filteredContacts = _contacts.where((contact) {
      final name = _displayName(contact).toLowerCase();
      final phone = _phone(contact) ?? '';
      final phoneNorm = PhoneMatcher.normalize(phone);
      if (queryDigits.isNotEmpty) {
        return phoneNorm.contains(queryDigits);
      }
      return name.contains(_searchQuery) ||
          phone.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  void _publishContacts({required bool loadingMore}) {
    _sortContacts();
    setState(() {
      _initialLoading = false;
      _loadingMore = loadingMore;
      _applyFilter();
    });
  }

  Future<void> _loadContacts() async {
    if (!mounted) return;

    setState(() {
      if (_contacts.isEmpty) {
        _initialLoading = true;
      } else {
        _loadingMore = true;
      }
    });

    final contactsRepo = ref.read(contactsRepositoryProvider);
    var page = 1;
    var hasMore = true;

    while (hasMore && mounted) {
      try {
        final paginated =
            await contactsRepo.listContactsPaginated(page: page, perPage: 100);
        final contacts = paginated['data'] as List<GekyContact>;
        _contacts.addAll(contacts);

        final meta = paginated['meta'] as Map<String, dynamic>;
        final currentPage = meta['current_page'] as int? ?? page;
        final lastPage = meta['last_page'] as int? ?? page;
        hasMore = currentPage < lastPage;
        page++;

        if (!mounted) return;
        _publishContacts(loadingMore: hasMore);
      } catch (e) {
        debugPrint('Error loading contacts page $page: $e');
        if (mounted) {
          _publishContacts(loadingMore: false);
        }
        break;
      }
    }

    if (mounted) {
      _publishContacts(loadingMore: false);
    }
  }

  Widget _buildLoadingState(Color mutedColor) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(strokeWidth: 2.5),
          const SizedBox(height: 16),
          Text(
            'Loading contacts...',
            style: TextStyle(
              color: mutedColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile(
    GekyContact contact,
    Color mutedColor,
    bool isDark,
  ) {
    final name = _displayName(contact);
    final phone = _phone(contact);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: ColoredAvatar(
        name: name,
        imageUrl: contact.avatarUrl,
        radius: 22,
      ),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: phone != null
          ? Text(
              phone,
              style: TextStyle(color: mutedColor),
            )
          : null,
      onTap: () => Navigator.pop(context, contact.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor =
        isDark ? const Color(0xFF8696A0) : const Color(0xFF667781);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.max,
        children: [
          Text(
            'Share Contact',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            enabled: !_initialLoading,
            decoration: InputDecoration(
              hintText: _initialLoading
                  ? 'Loading contacts...'
                  : 'Search contacts...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _searchController.clear,
                    )
                  : null,
              filled: true,
              fillColor:
                  isDark ? const Color(0xFF202C33) : const Color(0xFFF0F2F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _initialLoading
                ? _buildLoadingState(mutedColor)
                : _filteredContacts.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'No contacts available'
                              : 'No contacts match your search',
                          style: TextStyle(color: mutedColor),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        itemCount:
                            _filteredContacts.length + (_loadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= _filteredContacts.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: mutedColor,
                                  ),
                                ),
                              ),
                            );
                          }

                          return _buildContactTile(
                            _filteredContacts[index],
                            mutedColor,
                            isDark,
                          );
                        },
                      ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}
