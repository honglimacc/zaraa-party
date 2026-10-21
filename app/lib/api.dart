import 'dart:typed_data';

import 'package:dio/dio.dart';

class ApiError implements Exception {
  final String message;
  ApiError(this.message);
  @override
  String toString() => message;
}

/// Klien HTTP ke backend. Ubah alamat server dengan:
///   flutter run --dart-define=API_URL=https://api.domainmu.com
class Api {
  static final Api i = Api._();
  /// Client ID Google tipe Web (dari app_config.json saat build). Kosong = tombol Google disembunyikan.
  static const googleClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID', defaultValue: '');

  /// true bila alamat server sudah ditanam saat build, sehingga pengguna tidak perlu mengaturnya.
  static const serverBaked = String.fromEnvironment('API_URL', defaultValue: '') != '';

  /// Alamat server. Bisa diisi saat build (--dart-define=API_URL=...) atau diubah dari layar login.
  static String baseUrl = const String.fromEnvironment('API_URL', defaultValue: '');

  final Dio dio = Dio(BaseOptions(
    baseUrl: '$baseUrl/api',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  Api._();

  void setServer(String url) {
    baseUrl = url;
    dio.options.baseUrl = '$url/api';
  }

  void setToken(String? t) {
    if (t == null) {
      dio.options.headers.remove('Authorization');
    } else {
      dio.options.headers['Authorization'] = 'Bearer $t';
    }
  }

  Future<dynamic> _run(Future<Response> Function() f) async {
    try {
      return (await f()).data;
    } on DioException catch (e) {
      final d = e.response?.data;
      throw ApiError(d is Map && d['error'] != null ? '${d['error']}' : 'Tidak dapat terhubung ke server');
    }
  }

  /// Unggah byte mentah (gambar / Lottie JSON). Mengembalikan {url, kind, size}.
  Future<Map> upload(Uint8List bytes) async {
    final r = await _run(() => dio.post(
          '/upload',
          data: bytes,
          options: Options(contentType: 'application/octet-stream', headers: {Headers.contentLengthHeader: bytes.length}),
        ));
    return Map.from(r as Map);
  }

  Future<dynamic> get(String p, {Map<String, dynamic>? query}) => _run(() => dio.get(p, queryParameters: query));
  Future<dynamic> post(String p, [Object? body]) => _run(() => dio.post(p, data: body ?? {}));
  Future<dynamic> put(String p, Object body) => _run(() => dio.put(p, data: body));
  Future<dynamic> delete(String p) => _run(() => dio.delete(p));
}
