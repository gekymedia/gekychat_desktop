class BirthdayCelebrant {
  final int userId;
  final int? conversationId;
  final String name;
  final String? avatarUrl;
  final String? lastSeenLabel;
  final bool isSelf;

  const BirthdayCelebrant({
    required this.userId,
    this.conversationId,
    required this.name,
    this.avatarUrl,
    this.lastSeenLabel,
    this.isSelf = false,
  });

  factory BirthdayCelebrant.fromJson(Map<String, dynamic> json) {
    return BirthdayCelebrant(
      userId: json['user_id'] as int? ?? 0,
      conversationId: json['conversation_id'] as int?,
      name: json['name']?.toString() ?? 'Contact',
      avatarUrl: json['avatar_url']?.toString(),
      lastSeenLabel: json['last_seen_label']?.toString(),
      isSelf: json['is_self'] == true,
    );
  }
}

class BirthdaySummary {
  final String dismissKey;
  final int todayCount;
  final int yesterdayCount;
  final bool showBanner;
  final List<String> previewAvatars;
  final String bannerTitle;
  final String bannerSubtitle;
  final List<BirthdayCelebrant> today;
  final List<BirthdayCelebrant> yesterday;
  final BirthdayCelebrant? selfToday;
  final bool hasBirthdaySet;

  const BirthdaySummary({
    required this.dismissKey,
    required this.todayCount,
    required this.yesterdayCount,
    required this.showBanner,
    required this.previewAvatars,
    required this.bannerTitle,
    required this.bannerSubtitle,
    required this.today,
    required this.yesterday,
    this.selfToday,
    required this.hasBirthdaySet,
  });

  factory BirthdaySummary.empty() => const BirthdaySummary(
        dismissKey: '',
        todayCount: 0,
        yesterdayCount: 0,
        showBanner: false,
        previewAvatars: [],
        bannerTitle: '',
        bannerSubtitle: '',
        today: [],
        yesterday: [],
        hasBirthdaySet: true,
      );

  factory BirthdaySummary.fromJson(Map<String, dynamic> json) {
    List<BirthdayCelebrant> list(dynamic raw) {
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((e) => BirthdayCelebrant.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    final selfRaw = json['self_today'];
    return BirthdaySummary(
      dismissKey: json['dismiss_key']?.toString() ?? '',
      todayCount: json['today_count'] as int? ?? 0,
      yesterdayCount: json['yesterday_count'] as int? ?? 0,
      showBanner: json['show_banner'] == true,
      previewAvatars: (json['preview_avatars'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      bannerTitle: json['banner_title']?.toString() ?? '',
      bannerSubtitle: json['banner_subtitle']?.toString() ?? '',
      today: list(json['today']),
      yesterday: list(json['yesterday']),
      selfToday: selfRaw is Map
          ? BirthdayCelebrant.fromJson(Map<String, dynamic>.from(selfRaw))
          : null,
      hasBirthdaySet: json['has_birthday_set'] == true,
    );
  }
}
