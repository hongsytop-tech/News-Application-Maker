import 'package:supabase_flutter/supabase_flutter.dart';

/// Application-level view of an authenticated Supabase user.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
  });

  final String id;
  final String? email;

  factory AppUser.fromSupabase(User user) {
    return AppUser(id: user.id, email: user.email);
  }

  @override
  bool operator ==(Object other) =>
      other is AppUser && other.id == id && other.email == email;

  @override
  int get hashCode => Object.hash(id, email);
}
