import '../models/auth_user.dart';

abstract class AuthRepository {
  Future<AuthUser> login({required String login, required String password});
  Future<void> logout();
}

/// Dilempar saat login gagal; [message] aman ditampilkan ke staf.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}