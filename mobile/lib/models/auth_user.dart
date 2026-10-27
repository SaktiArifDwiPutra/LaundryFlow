class AuthUser {
  const AuthUser({
    required this.uid,
    required this.name,
    required this.username,
    required this.sessionId,
  });

  final int uid;
  final String name;
  final String username;
  final String sessionId;

  /// Dari isi `data` pada respons login backend.
  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      uid: json['uid'] as int,
      name: json['name'] as String,
      username: json['username'] as String,
      sessionId: json['session_id'] as String,
    );
  }
}