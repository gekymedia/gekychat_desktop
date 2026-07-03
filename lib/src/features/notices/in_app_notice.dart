/// Server-driven in-app banner (Telegram / WhatsApp Business style).
class InAppNotice {
  final int id;
  final String noticeKey;
  final String? title;
  final String body;
  final String style; // info | warning | promo
  final String? actionLabel;
  final String? actionUrl;

  const InAppNotice({
    required this.id,
    required this.noticeKey,
    this.title,
    required this.body,
    this.style = 'info',
    this.actionLabel,
    this.actionUrl,
  });

  factory InAppNotice.fromJson(Map<String, dynamic> json) {
    return InAppNotice(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      noticeKey: json['notice_key']?.toString() ?? '',
      title: json['title']?.toString(),
      body: json['body']?.toString() ?? '',
      style: json['style']?.toString() ?? 'info',
      actionLabel: json['action_label']?.toString(),
      actionUrl: json['action_url']?.toString(),
    );
  }
}
