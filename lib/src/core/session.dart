import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';
import '../features/calls/current_user_phone.dart';

class UserProfile {
  final int id;
  final String name;
  final String? phone;
  final String? avatarUrl;
  final String? username; // PHASE 2: Username for Mail and World Feed
  UserProfile({
    required this.id,
    required this.name,
    this.phone,
    this.avatarUrl,
    this.username,
  });
  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    id: j['id'], 
    name: j['name'] ?? 'User',
    phone: (j['phone'] as String?)?.trim(),
    avatarUrl: j['avatar_url'] as String?,
    username: j['username'] as String?,
  );
  
  bool get hasUsername => username != null && username!.isNotEmpty;
}

Future<UserProfile> _loadCurrentUserProfile(Ref ref) async {
  final api = ref.read(apiServiceProvider);
  final response = await api.get('/me');
  final raw = response.data;
  if (raw is Map) {
    final userJson = raw['data'] is Map ? raw['data'] as Map<String, dynamic> : Map<String, dynamic>.from(raw);
    final profile = UserProfile.fromJson(userJson);
    final phone = profile.phone;
    if (phone != null && phone.isNotEmpty) {
      await CurrentUserPhone.persistFromAuth(phone);
    }
    return profile;
  }
  throw Exception('Unexpected response payload for /me');
}

final currentUserProvider = FutureProvider<UserProfile>((ref) async {
  return _loadCurrentUserProfile(ref);
});

