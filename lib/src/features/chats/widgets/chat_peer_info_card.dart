import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../utils/avatar_utils.dart';
import '../../../utils/phone_country.dart';
import '../models.dart';

/// WhatsApp-style peer info card shown at the top of a DM thread.
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
    final blockBg = isDark ? const Color(0xFF3A1F24) : const Color(0xFFFDECEE);
    final blockFg = isDark ? const Color(0xFFFF6B6B) : const Color(0xFFD32F2F);

    final displayName = user.name.trim().isEmpty ? 'Unknown' : user.name.trim();
    final handle = (username != null && username!.trim().isNotEmpty)
        ? '@${username!.trim().replaceFirst(RegExp(r'^@'), '')}'
        : null;
    final origin = PhoneCountry.phoneOriginLabel(user.phone);
    final country = PhoneCountry.fromPhone(user.phone);
    final contactLabel = isContact ? 'In your contacts' : 'Not a contact';
    final groupsLabel = commonGroupsCount <= 0
        ? 'No common groups'
        : (commonGroupsCount == 1
            ? (commonGroupNames.isNotEmpty
                ? '1 group in common: ${commonGroupNames.first}'
                : '1 group in common')
            : '$commonGroupsCount groups in common');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Material(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onOpenProfile,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            child: Column(
              children: [
                _Avatar(user: user, displayName: displayName),
                const SizedBox(height: 14),
                if (handle != null) ...[
                  Text(
                    handle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: title,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '~$displayName',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 15),
                  ),
                ] else
                  Text(
                    displayName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: title,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: 12),
                if (loading)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: muted,
                      ),
                    ),
                  )
                else
                  Text.rich(
                    TextSpan(
                      style: TextStyle(color: muted, fontSize: 13.5, height: 1.45),
                      children: [
                        const TextSpan(text: 'Phone number from '),
                        TextSpan(
                          text: country ?? 'unknown region',
                          style: TextStyle(
                            color: title.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(text: '  ·  $contactLabel  ·  $groupsLabel'),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: onSafetyTools,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline, size: 18, color: accent),
                        const SizedBox(width: 6),
                        Text(
                          'Safety tools',
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (!isContact && onAddContact != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onAddContact,
                      icon: Icon(Icons.person_add_alt_1, color: accent),
                      label: Text(
                        'Add to contacts',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: accent.withValues(alpha: 0.45)),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onBlock,
                    icon: Icon(Icons.block, color: blockFg),
                    label: Text(
                      'Block',
                      style: TextStyle(
                        color: blockFg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: blockBg,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                  ),
                ),
                // Keep semantics for screen readers / tests
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, required this.displayName});

  final User user;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final url = user.avatarUrl;
    return CircleAvatar(
      radius: 40,
      backgroundColor: AvatarUtils.getColorForName(displayName),
      backgroundImage: (url != null && url.isNotEmpty)
          ? CachedNetworkImageProvider(url)
          : null,
      child: (url == null || url.isEmpty)
          ? Text(
              AvatarUtils.getInitials(displayName),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
    );
  }
}
