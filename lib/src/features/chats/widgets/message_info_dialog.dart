import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/api_service.dart';
import '../../../widgets/colored_avatar.dart';
import '../../../theme/app_theme.dart';

/// WhatsApp-style message info dialog showing read receipts
class MessageInfoDialog extends StatefulWidget {
  final int messageId;
  final bool isGroupMessage;
  final int currentUserId;

  const MessageInfoDialog({
    super.key,
    required this.messageId,
    required this.isGroupMessage,
    required this.currentUserId,
  });

  @override
  State<MessageInfoDialog> createState() => _MessageInfoDialogState();
}

class _MessageInfoDialogState extends State<MessageInfoDialog> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _messageInfo;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMessageInfo();
  }

  Future<void> _loadMessageInfo() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final endpoint = widget.isGroupMessage
          ? '/group-messages/${widget.messageId}/info'
          : '/messages/${widget.messageId}/info';
      
      final response = await _apiService.get(endpoint);
      setState(() {
        _messageInfo = response.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 500,
        height: 600,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF2A3942) : Colors.grey[300]!,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Message Info',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Failed to load message info',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.black54,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : _messageInfo == null
                          ? const Center(child: Text('No data available'))
                          : _buildContent(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    final sent = _messageInfo!['sent'] as Map<String, dynamic>? ?? {};
    final delivered = _messageInfo!['delivered'] as Map<String, dynamic>? ?? {};
    final read = _messageInfo!['read'] as Map<String, dynamic>? ?? {};
    final totalRecipients = _messageInfo!['total_recipients'] as int? ?? 0;
    final createdAt = _messageInfo!['created_at'] as String?;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Message timestamp
        if (createdAt != null)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkBackground : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                const SizedBox(width: 12),
                Text(
                  'Sent: ${_formatDateTime(createdAt)}',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

        // Read section
        _buildStatusSection(
          isDark,
          title: 'Read',
          icon: Icons.done_all,
          iconColor: AppTheme.primaryGreen,
          count: read['count'] as int? ?? 0,
          total: totalRecipients,
          users: (read['users'] as List<dynamic>?) ?? [],
        ),

        const SizedBox(height: 16),

        // Delivered section
        _buildStatusSection(
          isDark,
          title: 'Delivered',
          icon: Icons.done_all,
          iconColor: isDark ? Colors.white70 : Colors.black54,
          count: delivered['count'] as int? ?? 0,
          total: totalRecipients,
          users: (delivered['users'] as List<dynamic>?) ?? [],
        ),

        const SizedBox(height: 16),

        // Sent section
        _buildStatusSection(
          isDark,
          title: 'Sent',
          icon: Icons.check,
          iconColor: isDark ? Colors.white70 : Colors.black54,
          count: sent['count'] as int? ?? 0,
          total: totalRecipients,
          users: (sent['users'] as List<dynamic>?) ?? [],
        ),
      ],
    );
  }

  Widget _buildStatusSection(
    bool isDark, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required int count,
    required int total,
    required List<dynamic> users,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBackground : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '$count of $total',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (users.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'No users yet',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black38,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ...users.map((user) => _buildUserTile(
                  isDark,
                  user: user as Map<String, dynamic>,
                  status: title.toLowerCase(),
                )),
        ],
      ),
    );
  }

  Widget _buildUserTile(
    bool isDark, {
    required Map<String, dynamic> user,
    required String status,
  }) {
    final userName = user['user_name'] as String? ?? 'Unknown';
    final userAvatar = user['user_avatar'] as String?;
    final updatedAt = user['updated_at'] as String?;

    return ListTile(
      leading: ColoredAvatar(
        imageUrl: userAvatar,
        name: userName,
        radius: 20,
      ),
      title: Text(
        userName,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: updatedAt != null
          ? Text(
              _formatDateTime(updatedAt),
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black38,
                fontSize: 12,
              ),
            )
          : null,
      dense: true,
    );
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          if (difference.inMinutes == 0) {
            return 'Just now';
          }
          return '${difference.inMinutes}m ago';
        }
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return DateFormat('MMM d, y').format(dateTime);
      }
    } catch (e) {
      return dateTimeStr;
    }
  }
}
