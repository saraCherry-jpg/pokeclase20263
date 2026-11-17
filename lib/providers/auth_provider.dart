import 'package:flutter/material.dart';
import 'package:pokeclase20263/services/center_api.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({CenterApi? api}) : api = api ?? CenterApi.instance;
  final CenterApi api;
  bool cargando = false;
  String? error;
  Future<bool> _perform(Future<void> Function() action) async {
    if (cargando) return false;
    cargando = true;
    error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      cargando = false;
      notifyListeners();
    }
  }

  Future<bool> login(String name, String password) =>
      _perform(() => api.login(name, password));
  Future<bool> register(String name, String email, String password) =>
      _perform(() async {
        await api.request(
          '/api/Auth/register',
          method: 'POST',
          authenticated: false,
          body: {'userName': name, 'email': email, 'password': password},
        );
      });
}
