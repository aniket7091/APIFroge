import 'package:dio/dio.dart';

/// Singleton Dio instance configured to point at the APIForge backend.
abstract class ApiClient {
  static const String _baseUrl = String.fromEnvironment('API_URL', defaultValue: 'https://apiforge-backend-abtv.onrender.com');

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  static Dio get dio => _dio;

  static void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  static void clearToken() {
    _dio.options.headers.remove('Authorization');
  }
}
