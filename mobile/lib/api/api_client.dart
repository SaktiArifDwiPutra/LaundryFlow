import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_exception.dart';

const _networkMessage =
    'Tidak bisa terhubung ke server. Periksa internet atau alamat server.';

class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
    this.onUnauthorized,
    this.timeout = const Duration(seconds: 15),
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final Duration timeout;
  final http.Client _http;
  final void Function()? onUnauthorized;

  String? sessionId;
  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) =>
      _send('POST', path, body: body);

  Uri _uri(String path, Map<String, String>? query) {
    if (baseUrl.isEmpty) {
      throw const ApiException('Alamat server (BASE_URL) belum diatur.');
    }
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  String _defaultMessage(int code) {
    if (code == 401) return 'Tidak diizinkan. Silakan masuk lagi.';
    if (code == 403) return 'Akses ditolak.';
    if (code == 404) return 'Alamat layanan tidak ditemukan di server.';
    if (code >= 500) return 'Terjadi kesalahan di server.';
    return 'Permintaan gagal (kode $code).';
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final uri = _uri(path, query);
    final request = http.Request(method, uri)
      ..headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final session = sessionId;
    if (session != null) {
      request.headers['Authorization'] = 'Bearer $session';
    }

    final http.Response response;
    try {
      final streamed = await _http.send(request).timeout(timeout);
      response = await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      throw const ApiException('Server tidak menjawab. Coba lagi sebentar lagi.');
    } on IOException {
      throw const ApiException(_networkMessage);
    } on http.ClientException {
      throw const ApiException(_networkMessage);
    }

    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {
    }

    final ok = response.statusCode >= 200 && response.statusCode < 300;
    if (ok && json == null) {
      throw const ApiException('Respons server tidak valid.');
    }
    if (ok && json != null && json['success'] != false) return json;

    if (response.statusCode == 401 && sessionId != null) {
      sessionId = null;
      onUnauthorized?.call();
      throw const ApiException(
        'Sesi berakhir, silakan masuk lagi.',
        statusCode: 401,
      );
    }
    throw ApiException(
      (json?['message'] as String?) ?? _defaultMessage(response.statusCode),
      statusCode: response.statusCode,
    );
  }
}