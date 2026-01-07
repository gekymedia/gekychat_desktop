import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';

class UserProfile {
  final int id;
  final String name;
  final String? avatarUrl;
  final String? username; // PHASE 2: Username for Mail and World Feed
  UserProfile({required this.id, required this.name, this.avatarUrl, this.username});
  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    id: j['id'], 
    name: j['name'] ?? 'User', 
    avatarUrl: j['avatar_url'] as String?,
    username: j['username'] as String?,
  );
  
  bool get hasUsername => username != null && username!.isNotEmpty;
}

final currentUserProvider = FutureProvider<UserProfile>((ref) async {
  final api = ref.read(apiServiceProvider);
  final response = await api.get('/me');
  final raw = response.data;
  if (raw is Map) {
    final userJson = raw['data'] is Map ? raw['data'] as Map<String, dynamic> : Map<String, dynamic>.from(raw);
    return UserProfile.fromJson(userJson);
  }
  throw Exception('Unexpected response payload for /me');
});

