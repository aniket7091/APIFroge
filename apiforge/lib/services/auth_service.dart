import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../utils/storage_utils.dart';
import 'api_client.dart';

/// Manages authentication state: login, signup, logout, restore session.
class AuthService extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  String? _error;

  UserModel? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Called on app start to restore saved session token.
  Future<void> restoreSession() async {
    final token = StorageUtils.getToken();
    if (token != null) {
      try {
        ApiClient.setToken(token);
        final res = await ApiClient.dio.get('/auth/me');
        if (res.data['success'] == true) {
          _user = UserModel.fromJson(res.data['user']);
        }
      } catch (_) {
        await StorageUtils.removeToken();
        ApiClient.clearToken();
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> signup(String name, String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiClient.dio.post('/auth/signup', data: {
        'name': name, 'email': email, 'password': password,
      });
      if (res.data['success'] == true) {
        final token = res.data['token'] as String;
        await StorageUtils.setToken(token);
        ApiClient.setToken(token);
        _user = UserModel.fromJson(res.data['user']);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _error = res.data['message'] ?? 'Signup failed';
    } catch (e) {
      _error = _extractError(e);
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiClient.dio.post('/auth/login', data: {
        'email': email, 'password': password,
      });
      if (res.data['success'] == true) {
        final token = res.data['token'] as String;
        await StorageUtils.setToken(token);
        ApiClient.setToken(token);
        _user = UserModel.fromJson(res.data['user']);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _error = res.data['message'] ?? 'Login failed';
    } catch (e) {
      _error = _extractError(e);
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    await StorageUtils.removeToken();
    ApiClient.clearToken();
    _user = null;
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
