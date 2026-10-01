import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../utils/avatar_utils.dart';
import '../../../utils/phone_country.dart';
import '../models.dart';

/// Compact WhatsApp-style peer info card at the top of a DM thread.
class ChatPeerInfoCard extends StatelessWidget {
  const ChatPeerInfoCard({
    super.key,
    required this.user,
    this.username,
    required this.isContact,
    required this.commonGroupsCount,
    this.commonGroupNames = const [],
    this.loading = false,
    this.onSafetyTools,
    this.onBlock,
    this.onAddContact,
    this.onOpenProfile,
  });

  final User user;
  final String? username;
  final bool isContact;
  final int commonGroupsCount;
  final List<String> commonGroupNames;
  final bool loading;
  final VoidCallback? onSafetyTools;
  final VoidCallback? onBlock;
  final VoidCallback? onAddContact;
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1F2C34) : const Color(0xFFF0F2F5);
    final muted = isDark ? const Color(0xFF8696A0) : const Color(0xFF667781);
    final title = isDark ? Colors.white : const Color(0xFF111B21);
    final accent = const Color(0xFF00A884);
    final blockFg = isDark ? const Color(0xFFFF6B6B) : const Color(0xFFD32F2F);

    final displayName = user.name.trim().isEmpty ? 'Unknown' : user.name.trim();
    final handle = (username != null && username!.trim().isNotEmpty)
        ? '@${username!.trim().replaceFirst(RegExp(r'^@'), '')}'
        : null;
    final origin = PhoneCountry.phoneOriginLabel(user.phone);
    final country = PhoneCountry.fromPhone(user.phone);
    final contactLabel = isContact ? 'Contact' : 'Not a contact';
    final groupsLabel = commonGroupsCount <= 0
        ? 'No common groups'
        : (commonGroupsCount == 1
            ? (commonGroupNames.isNotEmpty
                ? '1 group in common'
                : '1 group in common')
            : '$commonGroupsCount groups in common');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Material(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onOpenProfile,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              children: [
                _Avatar(user: user, displayName: displayName),
                const SizedBox(height: 8),
                if (handle != null) ...[
                  Text(
                    handle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: title,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '~$displayName',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
                ] else
                  Text(
                    displayName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: title,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: 6),
                if (loading)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: muted,
                      ),
                    ),
                  )
                else
                  Text(
                    [
                      if (country != null) country,
                      contactLabel,
                      groupsLabel,
                    ].join('  ·  '),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: muted,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (!isContact && onAddContact != null)
                      _CompactAction(
                        icon: Icons.person_add_alt_1,
                        label: 'Add',
                        color: accent,
                        onTap: onAddContact,
                      ),
                    _CompactAction(
                      icon: Icons.info_outline,
                      label: 'Safety',
                      color: accent,
                      onTap: onSafetyTools,
                    ),
                    _CompactAction(
                      icon: Icons.block,
                      label: 'Block',
                      color: blockFg,
                      onTap: onBlock,
                    ),
                  ],
                ),
                Semantics(
                  label: origin,
                  child: const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactAction extends StatelessWidget {
  const _CompactAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, required this.displayName});

  final User user;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final url = user.avatarUrl;
    return CircleAvatar(
      radius: 28,
      backgroundColor: AvatarUtils.getColorForName(displayName),
      backgroundImage: (url != null && url.isNotEmpty)
          ? CachedNetworkImageProvider(url)
          : null,
      child: (url == null || url.isEmpty)
          ? Text(
              AvatarUtils.getInitials(displayName),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
    );
  }
}
