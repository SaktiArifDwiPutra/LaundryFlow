import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../config.dart';
import '../models/auth_user.dart';
import 'auth_repository.dart';

/// Login lewat POST /api/laundry/auth/login (lihat docs/api).
class OdooAuthRepository implements AuthRepository {
  OdooAuthRepository(this._api);

  final ApiClient _api;

  @override
  Future<AuthUser> login({
    required String login,
    required String password,
  }) async {
    try {
      final json = await _api.post(
        '/api/laundry/auth/login',
        body: {
          'login': login.trim(),
          'password': password,
          if (dbName.isNotEmpty) 'db': dbName,
        },
      );
      final user = AuthUser.fromJson(json['data'] as Map<String, dynamic>);
      _api.sessionId = user.sessionId;
      return user;
    } on ApiException catch (e) {
      throw AuthException(e.message);
    } on TypeError {
      throw const AuthException('Respons login dari server tidak sesuai harapan.');
    }
  }

  @override
  Future<void> logout() async {
    // Endpoint logout belum terlihat di backend, jadi hanya sesi lokal dihapus.
    _api.sessionId = null;
  }
}