import 'package:flutter/material.dart';
import '../models/request_model.dart';
import 'api_client.dart';

/// Manages saved API requests (CRUD).
class RequestService extends ChangeNotifier {
  List<RequestModel> _requests = [];
  bool _isLoading = false;
  String? _error;

  List<RequestModel> get requests => _requests;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchRequests({String? collectionId}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await ApiClient.dio.get('/requests',
          queryParameters: collectionId != null ? {'collectionId': collectionId} : null);
      if (res.data['success'] == true) {
        _requests = (res.data['data'] as List)
            .map((r) => RequestModel.fromJson(r as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<RequestModel?> saveRequest(RequestModel request) async {
    try {
      final res = await ApiClient.dio.post('/requests', data: request.toJson());
      if (res.data['success'] == true) {
        final saved = RequestModel.fromJson(res.data['data'] as Map<String, dynamic>);
        _requests.insert(0, saved);
        notifyListeners();
        return saved;
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
    return null;
  }

  Future<bool> updateRequest(String id, RequestModel request) async {
    try {
      final res = await ApiClient.dio.put('/requests/$id', data: request.toJson());
      if (res.data['success'] == true) {
        final updated = RequestModel.fromJson(res.data['data'] as Map<String, dynamic>);
        final idx = _requests.indexWhere((r) => r.id == id);
        if (idx >= 0) _requests[idx] = updated;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
    return false;
  }

  Future<bool> deleteRequest(String id) async {
    try {
      final res = await ApiClient.dio.delete('/requests/$id');
      if (res.data['success'] == true) {
        _requests.removeWhere((r) => r.id == id);
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
    return false;
  }
}
