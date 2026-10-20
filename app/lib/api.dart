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
  static const baseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:3000');

  final Dio dio = Dio(BaseOptions(
    baseUrl: '$baseUrl/api',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  Api._();

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

  Future<dynamic> get(String p, {Map<String, dynamic>? query}) => _run(() => dio.get(p, queryParameters: query));
  Future<dynamic> post(String p, [Object? body]) => _run(() => dio.post(p, data: body ?? {}));
  Future<dynamic> put(String p, Object body) => _run(() => dio.put(p, data: body));
  Future<dynamic> delete(String p) => _run(() => dio.delete(p));
}
