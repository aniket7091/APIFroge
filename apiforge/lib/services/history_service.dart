import 'package:flutter/material.dart';
import '../models/history_model.dart';
import 'api_client.dart';

/// Manages request history fetched from the backend.
class HistoryService extends ChangeNotifier {
  List<HistoryModel> _history = [];
  bool _isLoading = false;
  String? _error;

  List<HistoryModel> get history => _history;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchHistory() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiClient.dio.get('/history', queryParameters: {'limit': 100});
      if (res.data['success'] == true) {
        _history = (res.data['data'] as List)
            .map((h) => HistoryModel.fromJson(h as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> clearHistory() async {
    try {
      await ApiClient.dio.delete('/history');
      _history = [];
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteEntry(String id) async {
    try {
      await ApiClient.dio.delete('/history/$id');
      _history.removeWhere((h) => h.id == id);
      notifyListeners();
    } catch (_) {}
  }
}
