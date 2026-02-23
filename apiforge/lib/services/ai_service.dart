import 'package:flutter/material.dart';
import 'api_client.dart';
import 'proxy_service.dart';

class AiResult {
  final Map<String, dynamic> aiRequest;
  final ProxyResult proxyResponse;

  AiResult({required this.aiRequest, required this.proxyResponse});
}

class AiService extends ChangeNotifier {
  bool _isProcessing = false;
  String? _error;
  AiResult? _lastResult;

  bool get isProcessing => _isProcessing;
  String? get error => _error;
  AiResult? get lastResult => _lastResult;

  Future<AiResult?> executePrompt(String prompt, Map<String, dynamic> context) async {
    _isProcessing = true;
    _error = null;
    _lastResult = null;
    notifyListeners();

    try {
      final res = await ApiClient.dio.post('/ai/execute', data: {
        'prompt': prompt,
        'context': context,
      });

      if (res.data['success'] == true) {
        final data = res.data['data'];
        final aiReq = Map<String, dynamic>.from(data['aiRequest'] ?? {});
        final proxyRes = ProxyResult.fromJson(data['proxyResponse'] ?? {});
        
        _lastResult = AiResult(aiRequest: aiReq, proxyResponse: proxyRes);
      } else {
        _error = res.data['message'] ?? 'Unknown error from AI endpoint';
      }
    } catch (e) {
      _error = _extractError(e);
    }

    _isProcessing = false;
    notifyListeners();
    return _lastResult;
  }

  void clearResult() {
    _lastResult = null;
    _error = null;
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
