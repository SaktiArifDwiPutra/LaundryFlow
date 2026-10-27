import '../models/auth_user.dart';
import 'auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  // Akun PALSU, hanya untuk mock. Jangan pernah menaruh akun asli di kode.
  static const _mockLogin = 'staf';
  static const _mockPassword = 'staf123';

  @override
  Future<AuthUser> login({
    required String login,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));

    if (login.trim().isEmpty || password.isEmpty) {
      throw const AuthException('Username dan password wajib diisi');
    }
    if (login.trim() != _mockLogin || password != _mockPassword) {
      throw const AuthException('Username atau password salah');
    }

    // Bentuk sama dengan respons backend sungguhan (lihat docs/api).
    final Map<String, dynamic> response = {
      'success': true,
      'message': 'Login berhasil',
      'data': {
        'uid': 7,
        'name': 'Staf Satu',
        'username': 'staf',
        'session_id': 'mock-session-id',
      },
    };
    return AuthUser.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 200));
  }
}