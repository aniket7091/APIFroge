import 'package:flutter/material.dart';
import 'api_client.dart';
import '../models/request_model.dart';

/// Holds the result of a forwarded HTTP request.
class ProxyResult {
  final int statusCode;
  final String statusText;
  final Map<String, dynamic> headers;
  final dynamic body;
  final int responseTime;
  final int size;
  final bool isError;
  final String errorMessage;

  const ProxyResult({
    this.statusCode = 0,
    this.statusText = '',
    this.headers = const {},
    this.body,
    this.responseTime = 0,
    this.size = 0,
    this.isError = false,
    this.errorMessage = '',
  });

  factory ProxyResult.fromJson(Map<String, dynamic> json) => ProxyResult(
        statusCode: json['statusCode'] ?? 0,
        statusText: json['statusText'] ?? '',
        headers: Map<String, dynamic>.from(json['headers'] ?? {}),
        body: json['body'],
        responseTime: json['responseTime'] ?? 0,
        size: json['size'] ?? 0,
        isError: json['isError'] ?? false,
        errorMessage: json['errorMessage'] ?? '',
      );
}

/// Holds performance test results.
class PerformanceResult {
  final List<Map<String, dynamic>> results;
  final Map<String, dynamic> summary;
  const PerformanceResult({required this.results, required this.summary});
}

/// Sends API requests through the backend proxy and exposes state.
class ProxyService extends ChangeNotifier {
  ProxyResult? _lastResult;
  bool _isSending = false;
  String? _error;
  String _snippet = '';

  ProxyResult? get lastResult => _lastResult;
  bool get isSending => _isSending;
  String? get error => _error;
  String get snippet => _snippet;

  /// Sends a request via the backend proxy.
  Future<ProxyResult?> sendRequest({
    required String method,
    required String url,
    Map<String, String> headers = const {},
    Map<String, String> params = const {},
    dynamic body,
    String bodyType = 'none',
    AuthConfig? auth,
    Map<String, String> envVars = const {},
  }) async {
    // Interpolate environment variables {{VAR}} in url
    String resolvedUrl = url;
    for (final entry in envVars.entries) {
      resolvedUrl = resolvedUrl.replaceAll('{{${entry.key}}}', entry.value);
    }

    _isSending = true;
    _error = null;
    _lastResult = null;
    notifyListeners();

    try {
      final res = await ApiClient.dio.post('/proxy/send', data: {
        'method': method,
        'url': resolvedUrl,
        'headers': headers,
        'params': params,
        'body': body,
        'bodyType': bodyType,
        if (auth != null) 'auth': auth.toJson(),
      });

      final data = res.data['data'] as Map<String, dynamic>;
      _lastResult = ProxyResult.fromJson(data);
    } catch (e) {
      _error = _extractError(e);
      _lastResult = ProxyResult(isError: true, errorMessage: _error!);
    }

    _isSending = false;
    notifyListeners();
    return _lastResult;
  }

  /// Fetches a code snippet (curl or fetch) from the backend.
  Future<void> fetchSnippet({
    required String type,
    required String method,
    required String url,
    Map<String, String> headers = const {},
    Map<String, String> params = const {},
    dynamic body,
    AuthConfig? auth,
  }) async {
    try {
      final res = await ApiClient.dio.post('/proxy/snippet', data: {
        'type': type,
        'method': method,
        'url': url,
        'headers': headers,
        'params': params,
        'body': body,
        if (auth != null) 'auth': auth.toJson(),
      });
      _snippet = res.data['snippet'] ?? '';
    } catch (e) {
      _snippet = '// Error generating snippet';
    }
    notifyListeners();
  }

  /// Runs performance test.
  Future<PerformanceResult?> runPerformanceTest({
    required String method,
    required String url,
    Map<String, String> headers = const {},
    Map<String, String> params = const {},
    dynamic body,
    AuthConfig? auth,
    int iterations = 10,
  }) async {
    try {
      final res = await ApiClient.dio.post('/proxy/performance', data: {
        'method': method,
        'url': url,
        'headers': headers,
        'params': params,
        'body': body,
        'iterations': iterations,
        if (auth != null) 'auth': auth.toJson(),
      });
      final data = res.data['data'];
      return PerformanceResult(
        results: List<Map<String, dynamic>>.from(data['results']),
        summary: Map<String, dynamic>.from(data['summary']),
      );
    } catch (_) {
      return null;
    }
  }

  void clearResult() {
    _lastResult = null;
    _error = null;
    notifyListeners();
  }

  /// Manually set a result (e.g. from AI assistant)
  void setResult(ProxyResult result) {
    _lastResult = result;
    _error = result.isError ? result.errorMessage : null;
    notifyListeners();
  }

  String _extractError(dynamic e) {
    try {
      final data = (e as dynamic).response?.data;
      if (data is Map) return data['message'] ?? e.toString();
    } catch (_) {}
    return e.toString();
  }
}
