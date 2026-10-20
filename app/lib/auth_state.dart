import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api.dart';

class AuthState extends ChangeNotifier {
  final _store = const FlutterSecureStorage();

  String? token;
  Map<String, dynamic>? me;
  bool ready = false;

  String get role => (me?['role'] ?? 'user') as String;
  bool get isStaff => const ['admin', 'super_admin', 'developer'].contains(role);
  bool get isSuperAdmin => const ['super_admin', 'developer'].contains(role);
  bool get isDeveloper => role == 'developer';

  static String roleLabel(String r) => const {
        'user': 'User',
        'admin': 'Admin',
        'super_admin': 'Super Admin',
        'developer': 'Developer',
      }[r] ?? r;

  Future<void> init() async {
    token = await _store.read(key: 'token');
    if (token != null) {
      Api.i.setToken(token);
      try {
        await refresh();
      } catch (_) {
        await logout();
      }
    }
    ready = true;
    notifyListeners();
  }

  Future<void> refresh() async {
    me = Map<String, dynamic>.from(await Api.i.get('/me') as Map);
    notifyListeners();
  }

  Future<void> _auth(String path, Map<String, dynamic> body) async {
    final r = await Api.i.post(path, body);
    token = r['token'] as String;
    await _store.write(key: 'token', value: token);
    Api.i.setToken(token);
    await refresh();
  }

  Future<void> login(String username, String password) =>
      _auth('/auth/login', {'username': username, 'password': password});

  Future<void> register(String username, String password, String displayName) =>
      _auth('/auth/register', {'username': username, 'password': password, 'display_name': displayName});

  Future<void> logout() async {
    token = null;
    me = null;
    Api.i.setToken(null);
    await _store.delete(key: 'token');
    notifyListeners();
  }

  void setCoins(dynamic v) {
    me?['coins'] = v;
    notifyListeners();
  }
}
