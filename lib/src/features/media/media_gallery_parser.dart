import '../chats/models.dart';

class MediaGalleryLink {
  final String url;
  final String? title;

  const MediaGalleryLink({required this.url, this.title});
}

class MediaGalleryData {
  final List<MessageAttachment> images;
  final List<MessageAttachment> videos;
  final List<MessageAttachment> documents;
  final List<MediaGalleryLink> links;

  const MediaGalleryData({
    required this.images,
    required this.videos,
    required this.documents,
    required this.links,
  });

  bool get isEmpty =>
      images.isEmpty &&
      videos.isEmpty &&
      documents.isEmpty &&
      links.isEmpty;
}

final _urlPattern = RegExp(r'https?://[^\s<>"\)\]]+', caseSensitive: false);

MediaGalleryData parseMediaGalleryList(List<dynamic> list) {
  final images = <MessageAttachment>[];
  final videos = <MessageAttachment>[];
  final documents = <MessageAttachment>[];
  final links = <MediaGalleryLink>[];
  final seenLinks = <String>{};

  void addLink(String url, {String? title}) {
    final trimmed = url.trim();
    if (trimmed.isEmpty || seenLinks.contains(trimmed)) return;
    seenLinks.add(trimmed);
    links.add(MediaGalleryLink(url: trimmed, title: title));
  }

  void addAttachment(Map<String, dynamic> att) {
    final parsed = _parseAttachment(att);
    if (parsed == null) return;

    if (parsed.isImage) {
      images.add(parsed);
    } else if (parsed.isVideo) {
      videos.add(parsed);
    } else if (!parsed.isAudio) {
      documents.add(parsed);
    }
  }

  for (final item in list) {
    if (item == null) continue;
    final j = Map<String, dynamic>.from(item as Map);

    final linkPreviews = <Map<String, dynamic>>[];
    if (j['link_previews'] is List) {
      linkPreviews.addAll(
        (j['link_previews'] as List).whereType<Map<String, dynamic>>(),
      );
    }
    if (j['links'] is List) {
      linkPreviews.addAll(
        (j['links'] as List).whereType<Map<String, dynamic>>(),
      );
    }

    for (final lp in linkPreviews) {
      addLink(
        lp['url']?.toString() ?? '',
        title: lp['title']?.toString(),
      );
    }

    final body = j['body']?.toString() ?? '';
    if (body.isNotEmpty) {
      for (final match in _urlPattern.allMatches(body)) {
        addLink(match.group(0)!);
      }
    }

    final atts = <Map<String, dynamic>>[];
    if (j['attachments'] is List) {
      atts.addAll((j['attachments'] as List).whereType<Map<String, dynamic>>());
    }
    if (j['media'] is List) {
      atts.addAll((j['media'] as List).whereType<Map<String, dynamic>>());
    }
    if (j['files'] is List) {
      atts.addAll((j['files'] as List).whereType<Map<String, dynamic>>());
    }

    if (atts.isEmpty &&
        (j['url'] != null ||
            j['file_url'] != null ||
            j['type'] == 'image' ||
            j['type'] == 'video' ||
            j['type'] == 'document' ||
            j['type'] == 'file')) {
      atts.add(j);
    }

    for (final att in atts) {
      addAttachment(att);
    }
  }

  return MediaGalleryData(
    images: images,
    videos: videos,
    documents: documents,
    links: links,
  );
}

MessageAttachment? _parseAttachment(Map<String, dynamic> att) {
  try {
    if (att.containsKey('is_image') ||
        att.containsKey('is_video') ||
        att.containsKey('is_document')) {
      final parsed = MessageAttachment.fromJson(att);
      if (parsed.url.isEmpty) return null;
      return parsed;
    }
  } catch (_) {}

  var mime = att['mime_type']?.toString() ?? att['mimeType']?.toString() ?? '';
  final typeField = att['type']?.toString() ?? '';

  if (mime.isEmpty && typeField.isNotEmpty) {
    switch (typeField) {
      case 'image':
        mime = 'image/jpeg';
        break;
      case 'video':
        mime = 'video/mp4';
        break;
      case 'document':
        mime = 'application/octet-stream';
        break;
      case 'audio':
        mime = 'audio/mpeg';
        break;
    }
  }

  final url = att['url']?.toString() ??
      att['file_url']?.toString() ??
      att['src']?.toString() ??
      '';
  if (url.isEmpty) return null;

  final sharedAsDocument = att['shared_as_document'] == true;
  final isVoicenote = att['is_voicenote'] == true;

  var isImage = att['is_image'] == true ||
      (!sharedAsDocument && mime.startsWith('image/')) ||
      typeField == 'image';
  var isVideo = att['is_video'] == true ||
      (!sharedAsDocument && mime.startsWith('video/')) ||
      typeField == 'video';
  final isAudio = att['is_audio'] == true ||
      isVoicenote ||
      mime.startsWith('audio/') ||
      typeField == 'audio';

  if (sharedAsDocument) {
    isImage = false;
    isVideo = false;
  }

  final isDocument = att['is_document'] == true ||
      sharedAsDocument ||
      typeField == 'document' ||
      typeField == 'file' ||
      (!isImage && !isVideo && !isAudio);

  return MessageAttachment(
    id: _intField(att['id']) ?? 0,
    url: url,
    mimeType: mime.isEmpty ? 'application/octet-stream' : mime,
    isImage: isImage,
    isVideo: isVideo,
    isAudio: isAudio,
    isDocument: isDocument,
    originalName: att['original_name']?.toString() ??
        att['name']?.toString() ??
        att['filename']?.toString(),
    sharedAsDocument: sharedAsDocument,
    isVoicenote: isVoicenote,
    thumbnailUrl: att['thumbnail_url']?.toString() ?? att['thumb']?.toString(),
  );
}

int? _intField(dynamic v) {
  if (v is int) return v;
  if (v is String) return int.tryParse(v);
  return null;
}

List<dynamic> extractGalleryList(dynamic raw) {
  if (raw is Map) {
    return raw['data'] as List? ??
        raw['items'] as List? ??
        raw['messages'] as List? ??
        raw['media'] as List? ??
        [];
  }
  if (raw is List) return raw;
  return const [];
}
