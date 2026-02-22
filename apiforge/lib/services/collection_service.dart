import 'package:flutter/material.dart';
import '../models/collection_model.dart';
import 'api_client.dart';

/// Manages Collection CRUD state.
class CollectionService extends ChangeNotifier {
  List<CollectionModel> _collections = [];
  bool _isLoading = false;
  String? _error;

  List<CollectionModel> get collections => _collections;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchCollections() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiClient.dio.get('/collections');
      if (res.data['success'] == true) {
        _collections = (res.data['data'] as List)
            .map((c) => CollectionModel.fromJson(c as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      _error = _extractError(e);
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<CollectionModel?> createCollection(String name, String description, String color) async {
    try {
      final res = await ApiClient.dio.post('/collections', data: {
        'name': name, 'description': description, 'color': color,
      });
      if (res.data['success'] == true) {
        final c = CollectionModel.fromJson(res.data['data'] as Map<String, dynamic>);
        _collections.insert(0, c);
        notifyListeners();
        return c;
      }
    } catch (e) {
      _error = _extractError(e);
      notifyListeners();
    }
    return null;
  }

  Future<bool> updateCollection(String id, String name, String description) async {
    try {
      final res = await ApiClient.dio.put('/collections/$id',
          data: {'name': name, 'description': description});
      if (res.data['success'] == true) {
        final updated = CollectionModel.fromJson(res.data['data'] as Map<String, dynamic>);
        final idx = _collections.indexWhere((c) => c.id == id);
        if (idx >= 0) _collections[idx] = updated;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = _extractError(e);
      notifyListeners();
    }
    return false;
  }

  Future<bool> deleteCollection(String id) async {
    try {
      final res = await ApiClient.dio.delete('/collections/$id');
      if (res.data['success'] == true) {
        _collections.removeWhere((c) => c.id == id);
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = _extractError(e);
      notifyListeners();
    }
    return false;
  }

  String _extractError(dynamic e) {
    try {
      final data = (e as dynamic).response?.data;
      if (data is Map) return data['message'] ?? e.toString();
    } catch (_) {}
    return e.toString();
  }
}
