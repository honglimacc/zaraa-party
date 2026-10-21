import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api.dart';
import 'l10n.dart';
import 'realtime.dart';

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

  /// Rapikan input alamat server: tambahkan https:// bila tidak ada, buang garis miring di akhir.
  static String normalizeUrl(String v) {
    var u = v.trim();
    if (u.isEmpty) return '';
    if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'https://$u';
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  Future<void> setServer(String url) async {
    final u = normalizeUrl(url);
    Api.i.setServer(u);
    await _store.write(key: 'server_url', value: u);
    notifyListeners();
  }

  Future<void> init() async {
    final saved = await _store.read(key: 'server_url');
    if (saved != null && saved.isNotEmpty) Api.i.setServer(saved);
    else if (Api.baseUrl.isNotEmpty) Api.i.setServer(Api.baseUrl);
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
    L.lang = (me!['language'] ?? 'id') as String;
    Rt.i.connect(token);
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

  Future<void> register(String username, String password, String displayName, {String? inviteCode}) =>
      _auth('/auth/register', {
        'username': username,
        'password': password,
        'display_name': displayName,
        if (inviteCode != null && inviteCode.isNotEmpty) 'invite_code': inviteCode,
      });

  Future<void> setLanguage(String lang) async {
    await Api.i.put('/me', {'language': lang});
    L.lang = lang;
    me?['language'] = lang;
    notifyListeners();
  }

  /// Masuk / daftar dengan akun Google. Server memverifikasi id_token ke Google.
  Future<void> loginWithGoogle() async {
    final gs = GoogleSignIn(serverClientId: Api.googleClientId, scopes: ['email']);
    try {
      await gs.signOut(); // selalu tampilkan pilihan akun
      final acc = await gs.signIn();
      if (acc == null) return; // dibatalkan pengguna
      final idToken = (await acc.authentication).idToken;
      if (idToken == null) throw ApiError('Google tidak mengirim token. Periksa Client ID.');
      await _auth('/auth/google', {'id_token': idToken});
    } on PlatformException catch (e) {
      throw ApiError('Login Google gagal (${e.code}). Pastikan SHA-1 dan Client ID sudah benar.');
    }
  }

  /// Hapus akun permanen lalu keluar.
  Future<void> deleteAccount() async {
    await Api.i.delete('/me');
    await logout();
  }

  Future<void> logout() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    Rt.i.disconnect();
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
